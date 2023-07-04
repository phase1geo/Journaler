using Gtk;

public class Preferences : Gtk.Dialog {

  private MainWindow _win;
  private MenuButton _theme_mb;

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
    stack.add_titled( create_general(), "general",  _( "General" ) );
    stack.add_titled( create_editor(),  "editor",   _( "Editor" ) );

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

    grid.attach( make_label( _( "Weather Location" ) ), 0, 0 );
    grid.attach( make_entry( "weather-location", _( "Enter zip code, city or nearest 3 character airport code" ), 20 ), 1, 0 );

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
