using Gtk;

public class Preferences : Gtk.Dialog {

  private MainWindow _win;
  private MenuButton _theme_mb;
  private Grid       _feed_grid;

  private const GLib.ActionEntry action_entries[] = {
    { "action_set_current_theme", action_set_current_theme, "s" }
  };

  private delegate string ValidateEntryCallback( Entry entry, string text, int position );

  /* Default constructor */
  public Preferences( MainWindow win ) {

    Object(
      deletable: false,
      resizable: false,
      title: _("Preferences"),
      transient_for: win
    );

    _win = win;

    var stack = new Stack() {
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 24,
      margin_bottom = 18
    };
    stack.add_titled( create_general(),    "general", _( "General" ) );
    stack.add_titled( create_editor(),     "editor",  _( "Editor" ) );
    stack.add_titled( create_news_feeds(), "feeds",   _( "News Feeds" ) );

    var switcher = new StackSwitcher() {
      halign = Align.CENTER
    };
    switcher.set_stack( stack );

    var box = new Box( Orientation.VERTICAL, 0 );
    box.append( switcher );
    box.append( stack );

    get_content_area().append( box );

    /* Create close button at bottom of window */
    var close_button = new Button.with_label( _( "Close" ) );
    close_button.clicked.connect(() => {
      save_news_feeds();
      destroy();
    });

    add_action_widget( close_button, 0 );

    /* Add the menu actions */
    var actions = new SimpleActionGroup();
    actions.add_action_entries( action_entries, this );
    insert_action_group( "prefs", actions );

  }

  /* Creates the general panel */
  private Grid create_general() {

    var grid = new Grid() {
      row_spacing = 5,
      column_spacing = 5
    };

    return( grid );

  }

  /* Creates the editor panel */
  private Grid create_editor() {

    var grid = new Grid() {
      row_spacing = 5,
      column_spacing = 5
    };

    grid.attach( make_label( _( "Default Theme" ) ), 0, 0 );
    grid.attach( make_themes(), 1, 0, 2 );

    grid.attach( make_label( _( "Editor Font Size" ) ), 0, 1 );
    grid.attach( make_spinner( "editor-font-size", 8, 24, 1 ), 1, 1 );

    grid.attach( make_label( _( "Editor Margin" ) ), 0, 2 );
    grid.attach( make_spinner( "editor-margin", 5, 100, 5 ), 1, 2 );

    grid.attach( make_label( _( "Editor Line Spacing" ) ), 0, 3 );
    grid.attach( make_spinner( "editor-line-spacing", 2, 20, 1 ), 1, 3 );

    return( grid );

  }

  /* Adds a feed row at the given position */
  private void add_feed_row( Grid grid, int position, NewsSource? source = null ) {

    var name = new Entry() {
      placeholder_text = _( "Name" ),
      max_length = 20
    };

    var feed = new Entry() {
      placeholder_text = _( "Feed URL" ),
      halign = Align.FILL,
      hexpand = true
    };

    var items = new SpinButton.with_range( 1, 20, 1 );

    var add = new Button.from_icon_name( "list-add-symbolic" ) {
      margin_start = 15
    };
    add.clicked.connect(() => {
      int col, row, wspan, hspan;;
      grid.query_child( name, out col, out row, out wspan, out hspan );
      add_feed_row( grid, (row + 1) );
    });

    var del = new Button.from_icon_name( "list-remove-symbolic" );
    del.clicked.connect(() => {
      int col, row, wspan, hspan;
      grid.query_child( name, out col, out row, out wspan, out hspan );
      grid.remove_row( row );
      if( grid.get_child_at( 0, 0 ) == null ) {
        add_feed_row( grid, 0 );
      }
    });

    /* Insert the new row with widgets */
    grid.insert_row( position );
    grid.attach( name,  0, position );
    grid.attach( feed,  1, position );
    grid.attach( items, 2, position );
    grid.attach( add,   3, position );
    grid.attach( del,   4, position );

    /* Populate the widgets if we have data to show */
    if( source != null ) {
      name.text   = source.name;
      feed.text   = source.feed;
      items.value = (double)source.num_items;
    }

    name.grab_focus();

  }

  /* Creates the news feed panel */
  private ScrolledWindow create_news_feeds() {

    _feed_grid = new Grid() {
      row_spacing = 5,
      column_spacing = 5
    };

    var scroll = new ScrolledWindow() {
      vscrollbar_policy = PolicyType.AUTOMATIC,
      hscrollbar_policy = PolicyType.NEVER,
      child = _feed_grid
    };
    scroll.set_size_request( 500, 300 );

    var vars = _win.templates.template_vars;
    if( vars.num_news_source() == 0 ) {
      add_feed_row( _feed_grid, 0 );
    } else {
      for( int i=0; i<vars.num_news_source(); i++ ) {
        add_feed_row( _feed_grid, i, vars.get_news_source( i ) );
      }
    }

    return( scroll );

  }

  private void save_news_feeds() {

    var row = 0;
    var vars = _win.templates.template_vars;

    vars.clear_news_sources();

    do {
      if( _feed_grid.get_child_at( 0, row ) != null ) {
        var name  = (Entry)_feed_grid.get_child_at( 0, row ); 
        var feed  = (Entry)_feed_grid.get_child_at( 1, row );
        var items = (SpinButton)_feed_grid.get_child_at( 2, row );
        if( (name != null) && (name.text != "") && (feed.text != "") ) {
          var source = new NewsSource( name.text, feed.text, (int)items.value );
          vars.add_news_source( source );
        }
        row++;
      }
    } while( _feed_grid.get_child_at( 0, row ) != null );

    vars.save_news_sources();

    Idle.add(() => {
      vars.update_news();
      return( false );
    });

  }

  /* Creates label */
  private Label make_label( string label ) {
    var w = new Label( label ) {
      halign = Align.END
    };
    return( w );
  }

  /* Creates switch */
  private Switch make_switch( string setting ) {
    var w = new Switch() {
      halign = Align.START,
      valign = Align.CENTER
    };
    Journaler.settings.bind( setting, w, "active", SettingsBindFlags.DEFAULT );
    return( w );
  }

  /* Creates spinner */
  private SpinButton make_spinner( string setting, int min_value, int max_value, int step ) {
    var w = new SpinButton.with_range( min_value, max_value, step );
    Journaler.settings.bind( setting, w, "value", SettingsBindFlags.DEFAULT );
    return( w );
  }

  /* Creates an entry */
  private Entry make_entry( string setting, string placeholder, int max_length = 30, ValidateEntryCallback? cb = null ) {
    var w = new Entry() {
      placeholder_text        = placeholder,
      max_length              = max_length,
      enable_emoji_completion = false
    };
    if( cb != null ) {
      w.insert_text.connect((new_text, new_text_length, ref position) => {
        var cleaned = cb( w, new_text, position );
        if( cleaned != new_text ) {
          handle_text_insertion( w, cleaned, ref position );
        }
      });
    }
    Journaler.settings.bind( setting, w, "text", SettingsBindFlags.DEFAULT );
    return( w );
  }

  /* Helper function for the make_entry method */
  private void handle_text_insertion( Entry entry, string cleaned, ref int position ) {
    var void_entry = (void*)entry;
    SignalHandler.block_by_func( void_entry, (void*)handle_text_insertion, this );
    entry.insert_text( cleaned, cleaned.length, ref position );
    SignalHandler.unblock_by_func( void_entry, (void*)handle_text_insertion, this );
    Signal.stop_emission_by_name( entry, "insert_text" );
  }

  /* Creates an information image */
  private Image make_info( string detail ) {
    var w = new Image.from_icon_name( "dialog-information-symbolic" ) {
      halign       = Align.START,
      tooltip_text = detail
    };
    return( w );
  }

  /* Creates the theme menu button */
  private MenuButton make_themes() {

    var menu = new GLib.Menu();

    _theme_mb = new MenuButton() {
      label      = _win.themes.theme,
      menu_model = menu
    };

    /* Get the available theme names */
    for( int i=0; i<_win.themes.size(); i++ ) {
      menu.append( _win.themes.index( i ).name, "prefs.action_set_current_theme('%s')".printf( _win.themes.index( i ).name ) );
    }

    return( _theme_mb );

  }

  /* Handles any changes to the theme */
  private void action_set_current_theme( SimpleAction action, Variant? variant ) {

    var theme = variant.get_string();

    _theme_mb.label = theme;

    /* Update the settings */
    Journaler.settings.set_string( "default-theme", theme );

    /* Indicate that the theme changed for the rest of the UI */
    _win.themes.theme = theme;

  }

}
