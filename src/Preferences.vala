using Gtk;
using Gee;

public class Preferences : Gtk.Dialog {

  private MainWindow _win;
  private Journals   _journals;
  private MenuButton _theme_mb;
  private Grid       _feed_grid;
  private HashMap<string,MenuButton> _menus;
  private MenuButton _journal_mb;
  private MenuButton _format_mb;
  private MenuButton _import_mb;
  private Button     _import;
  private Entry      _new_entry;
  private bool       _new_entry_shown = false;
  private string     _journal_name = "";
  private string     _format_name  = "xml";

  private const GLib.ActionEntry action_entries[] = {
    { "action_set_current_theme",         action_set_current_theme,         "s" },
    { "action_lock_menu",                 action_lock_menu,                 "i" },
    { "action_select_journal_for_export", action_select_journal_for_export, "s" },
    { "action_select_export_format",      action_select_export_format,      "s" },
    { "action_select_import_journal",     action_select_import_journal,     "s" },
    { "action_select_new_import_journal", action_select_new_import_journal }
  };

  public signal void closing();

  private delegate string ValidateEntryCallback( Entry entry, string text, int position );

  /* Default constructor */
  public Preferences( MainWindow win, Journals journals ) {

    Object(
      deletable: false,
      resizable: false,
      title: _("Preferences"),
      transient_for: win,
      modal: true
    );

    _win      = win;
    _journals = journals;
    _menus    = new HashMap<string,MenuButton>();

    var stack = new Stack() {
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 24,
      margin_bottom = 18
    };
    stack.add_titled( create_general(),    "general",  _( "General" ) );
    stack.add_titled( create_editor(),     "editor",   _( "Editor" ) );
    stack.add_titled( create_news_feeds(), "feeds",    _( "News Feeds" ) );
    stack.add_titled( create_advanced(),   "advanced", _( "Advanced" ) );

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
      _win.reset_timer();
      save_news_feeds();
      close();
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
      column_spacing = 5,
      halign = Align.CENTER
    };

    var entry_preview = new Label( "" ) {
      label  = Utils.build_entry_title( Journaler.settings.get_string( "entry-title-prefix" ), Journaler.settings.get_string( "entry-title-suffix" ) ),
      halign = Align.START
    };

    grid.attach( make_label( _( "Automatically lock application" ) ), 0, 0 );
    grid.attach( make_menu( "auto-lock", lock_label(), create_lock_menu() ), 1, 0 );

    grid.attach( make_label( "" ), 0, 1 );

    grid.attach( make_label( _( "Default Entry Title" ) ), 0, 2 );
    grid.attach( make_entry( "entry-title-prefix", _( "Prefix" ), 30, (entry, text, position) => {
      entry_preview.label = Utils.build_entry_title( text, Journaler.settings.get_string( "entry-title-suffix" ) );
      return( text );
    }), 1, 2 );
    grid.attach( make_entry( "entry-title-suffix", _( "Suffix" ), 30, (entry, text, position) => {
      entry_preview.label = Utils.build_entry_title( Journaler.settings.get_string( "entry-title-prefix" ), text );
      return( text );
    }), 1, 3 );
    grid.attach( make_label( _( "Preview:" ) ), 0, 4 );
    grid.attach( entry_preview, 1, 4 );

    /* Disable the menubutton if we haven't setup a password yet */
    if( !Security.does_password_exist() ) {
      var mb = (MenuButton)grid.get_child_at( 1, 0 );
      mb.sensitive = false;
      grid.attach( make_info( _( "This option is only available once the user has created a password.\n\nTo create a password, close the preferences window, click on the\nLock icon in the headerbar, and create your password." ) ), 2, 0 );
    }

    return( grid );

  }

  /* Create the application auto-lock menu */
  private GLib.Menu create_lock_menu() {

    var menu = new GLib.Menu();
    GLib.Menu? submenu = null;

    for( int i=0; i<AutoLockOption.NUM; i++ ) {
      var opt = (AutoLockOption)i;
      if( opt.new_menu() ) {
        if( submenu != null ) {
          menu.append_section( null, submenu );
        }
        submenu = new GLib.Menu();
      }
      submenu.append( opt.label(), "prefs.action_lock_menu(%d)".printf( i ) );
    }
    menu.append_section( null, submenu );

    return( menu );

  }

  /* Returns the lock menubutton label */
  private string lock_label() {
    var opt = (AutoLockOption)Journaler.settings.get_int( "auto-lock" );
    return( opt.label() );
  }

  /* Sets the lock menu to the given value */
  private void action_lock_menu( SimpleAction action, Variant? variant ) {
    _win.reset_timer();
    var opt = (AutoLockOption)variant.get_int32();
    _menus.get( "auto-lock" ).label = opt.label();
    Journaler.settings.set_int( "auto-lock", variant.get_int32() );
  }

  /* Creates the editor panel */
  private Grid create_editor() {

    var grid = new Grid() {
      row_spacing = 5,
      column_spacing = 5,
      halign = Align.CENTER
    };

    grid.attach( make_label( _( "Default Theme" ) ), 0, 0 );
    grid.attach( make_themes(), 1, 0, 2 );

    grid.attach( make_label( _( "Font Size" ) ), 0, 1 );
    grid.attach( make_spinner( "editor-font-size", 8, 24, 1 ), 1, 1 );

    grid.attach( make_label( _( "Margin" ) ), 0, 2 );
    grid.attach( make_spinner( "editor-margin", 5, 100, 5 ), 1, 2 );

    grid.attach( make_label( _( "Line Spacing" ) ), 0, 3 );
    grid.attach( make_spinner( "editor-line-spacing", 2, 20, 1 ), 1, 3 );

    grid.attach( make_spacer(), 0, 4 );

    grid.attach( make_label( _( "Character Count Goal" ) ), 0, 5 );
    grid.attach( make_spinner( "character-goal", 100, 100000, 100 ), 1, 5 );

    grid.attach( make_label( _( "Word Count Goal" ) ), 0, 6 );
    grid.attach( make_spinner( "word-goal", 50, 5000, 50 ), 1, 6 );

    return( grid );

  }

  /* Adds a feed row at the given position */
  private void add_feed_row( Grid grid, int position, NewsSource? source = null ) {

    var name = new Entry() {
      placeholder_text = _( "Name" ),
      max_length = 20
    };
    name.changed.connect( _win.reset_timer );

    var feed = new Entry() {
      placeholder_text = _( "Feed URL" ),
      halign = Align.FILL,
      hexpand = true
    };
    feed.changed.connect( _win.reset_timer );

    var items = new SpinButton.with_range( 1, 20, 1 );
    items.value_changed.connect( _win.reset_timer );

    var add = new Button.from_icon_name( "list-add-symbolic" ) {
      margin_start = 15
    };
    add.clicked.connect(() => {
      int col, row, wspan, hspan;;
      grid.query_child( name, out col, out row, out wspan, out hspan );
      add_feed_row( grid, (row + 1) );
      _win.reset_timer();
    });

    var del = new Button.from_icon_name( "list-remove-symbolic" );
    del.clicked.connect(() => {
      int col, row, wspan, hspan;
      grid.query_child( name, out col, out row, out wspan, out hspan );
      grid.remove_row( row );
      if( grid.get_child_at( 0, 0 ) == null ) {
        add_feed_row( grid, 0 );
      }
      _win.reset_timer();
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

  /* Creates the preference panel for the login screens */
  private Box create_login() {

    var lbl = new Label( Utils.make_title( _( "Select a Login Screen Background" ) ) ) {
      use_markup = true
    };

    var login_box = new FlowBox() {
      row_spacing    = 5,
      column_spacing = 5,
      halign         = Align.FILL,
      valign         = Align.FILL,
      hexpand        = true,
      vexpand        = true,
      homogeneous    = true,
      margin_end     = 10
    };

    login_box.child_activated.connect((child) => {
      _win.reset_timer();
      if( (child.child as Button) == null ) { 
        _win.locker.current = child.get_index();
      }
    });

    for( int i=0; i<_win.locker.size(); i++ ) {
      add_login_image( login_box, i );
    }

    var pentry = new Entry() {
      placeholder_text = _( "Enter image filename or URL" )
    };

    var pbrowse = new Button.with_label( _( "Browse…" ) );
    var pbox = new Box( Orientation.HORIZONTAL, 5 ) {
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };
    pbox.append( pentry );
    pbox.append( pbrowse );

    var popover = new Popover() {
      child = pbox
    };

    pentry.changed.connect(() => {
      _win.reset_timer();
    });

    pentry.activate.connect(() => {
      _win.reset_timer();
      var uri = pentry.text;
      if( uri != "" ) {
        if( FileUtils.test( uri, FileTest.EXISTS ) && !uri.has_prefix( "file://" ) ) {
          uri = "file://%s".printf( uri );
        }
        _win.locker.add_uri_image( uri );
        add_login_image( login_box, (_win.locker.size() - 1) );
        pentry.text = "";
      }
      popover.popdown();
    });

    pbrowse.clicked.connect(() => {
      _win.reset_timer();
      popover.popdown();
      var dialog = Utils.make_file_chooser( _( "Select an image" ), this, FileChooserAction.OPEN, _( "Choose Image" ) );
      dialog.response.connect((id) => {
        _win.reset_timer();
        if( id == ResponseType.ACCEPT ) {
          var file = dialog.get_file();
          if( file != null ) {
            pentry.text = file.get_path();
            pentry.activate();
          }
        }
        dialog.close();
      });
      dialog.show();
    });

    var add_button = new MenuButton() {
      icon_name = "list-add-symbolic",
      has_frame = true,
      popover   = popover
    };
    add_button.activate.connect(() => {
      _win.reset_timer();
    });
    add_button.add_css_class( "login-thumbnail" );
    login_box.append( add_button );

    /* Select the current theme */
    var flow_child = login_box.get_child_at_index( _win.locker.current );
    login_box.select_child( flow_child );

    var scroll = new ScrolledWindow() {
      child = login_box
    };

    var box = new Box( Orientation.VERTICAL, 5 );
    box.append( lbl );
    box.append( scroll );

    return( box );

  }

  /* Adds a login image to the given flowbox using the locker index */
  private void add_login_image( FlowBox flowbox, int index ) {

    var box = new Box( Orientation.VERTICAL, 5 ) {
      halign        = Align.FILL,
      valign        = Align.FILL,
      hexpand       = true,
      vexpand       = true,
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };
    box.set_size_request( 75, 50 );
    box.add_css_class( _win.locker.css_class( index ) );
    box.add_css_class( "login-thumbnail" );
     
    if( !_win.locker.is_built_in( index ) ) {
      var motion  = new EventControllerMotion();
      var overlay = new Overlay() {
        child = box
      };
      overlay.add_controller( motion );
      var remove = new Button.from_icon_name( "window-close-symbolic" ) {
        halign    = Align.END,
        valign    = Align.START,
        has_frame = true
      };
      remove.add_css_class( "login-thumbnail" );
      remove.add_css_class( Granite.STYLE_CLASS_BACKGROUND );
      remove.hide();
      remove.clicked.connect(() => {
        _win.reset_timer();
        var child = (FlowBoxChild)overlay.get_parent();
        var idx   = child.get_index();
        if( _win.locker.current == idx ) {
          _win.locker.current = ((idx + 1) == _win.locker.size()) ? (idx - 1) : idx;
          flowbox.select_child( flowbox.get_child_at_index( _win.locker.current ) );
        }
        _win.locker.remove_image( idx );
        flowbox.remove( overlay );
      });
      motion.enter.connect((x, y) => {
        _win.reset_timer();
        remove.show();
      });
      motion.leave.connect(() => {
        _win.reset_timer();
        remove.hide();
      });
      overlay.add_overlay( remove );
      flowbox.insert( overlay, index );
    } else {
      flowbox.insert( box, index );
    }

  }

  /* Creates the news feed panel */
  private ScrolledWindow create_news_feeds() {

    _feed_grid = new Grid() {
      row_spacing = 5,
      column_spacing = 5,
      halign = Align.CENTER
    };

    var scroll = new ScrolledWindow() {
      vscrollbar_policy = PolicyType.AUTOMATIC,
      hscrollbar_policy = PolicyType.NEVER,
      child = _feed_grid
    };
    scroll.set_size_request( 500, 300 );
    scroll.scroll_child.connect((t,h) => {
      _win.reset_timer();
      return( true );
    });

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

  /* Creates advanced pane */
  private Box create_advanced() {

    var box = new Box( Orientation.VERTICAL, 5 );
    box.append( create_advanced_export() );
    box.append( create_advanced_import() );

    return( box );

  }

  /* Creates the export frame for the Advanced panel */
  private Frame create_advanced_export() {

    /* Export */
    var all = new CheckButton.with_label( _( "Export all journals" ) ) {
      active = true
    };
    var one = new CheckButton.with_label( _( "Export journal" ) ) {
      group = all
    };

    var journals_menu = new GLib.Menu();
    for( int i=0; i<_journals.num_journals(); i++ ) {
      var journal = _journals.get_journal( i );
      journals_menu.append( journal.name, "prefs.action_select_journal_for_export('%s')".printf( journal.name ) );
    }

    _journal_mb = new MenuButton() {
      label      = (_journals.num_journals() == 0) ? "" : _journals.get_journal( 0 ).name,
      sensitive  = false,
      menu_model = journals_menu
    };

    var obox = new Box( Orientation.HORIZONTAL, 5 );
    obox.append( one );
    obox.append( _journal_mb );

    all.toggled.connect(() => {
      _win.reset_timer();
    });
    one.toggled.connect(() => {
      _win.reset_timer();
      _journal_mb.sensitive = one.active;
    });

    var for_import = new CheckButton.with_label( _( "Export for the purpose of importing back into Journaler" ) ) {
      margin_top = 10
    };
    var include_images = new CheckButton.with_label( _( "Include entry images" ) );

    var format_menu = new GLib.Menu();
    for( int i=0; i<_win.exports.length(); i++ ) {
      format_menu.append( _win.exports.index( i ).label, "prefs.action_select_export_format('%s')".printf( _win.exports.index( i ).name ) );
    }

    var format = new Label( _( "Export Format:" ) );
    _format_mb = new MenuButton() {
      label      = _( "XML" ),
      menu_model = format_menu
    };

    for_import.toggled.connect(() => {
      _win.reset_timer();
      if( for_import.active ) {
        include_images.active    = true;
        include_images.sensitive = false;
        _format_mb.sensitive     = false;
      } else {
        include_images.active    = false;
        include_images.sensitive = true;
        _format_mb.sensitive     = true;
      }
    });

    include_images.toggled.connect(() => {
      _win.reset_timer();
    });

    var export = new Button.with_label( _( "Export…" ) ) {
      halign  = Align.END,
      hexpand = true
    };
    export.clicked.connect(() => {
      _win.reset_timer();
      var journal = all.active ? "" : _journal_name;
      do_export( journal, for_import.active, include_images.active, _format_name );
    });

    var bbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign  = Align.FILL,
      hexpand = true
    };
    bbox.append( format );
    bbox.append( _format_mb );
    bbox.append( export );

    var egrid = new Grid() {
      row_spacing        = 5,
      column_spacing     = 5,
      halign             = Align.FILL,
      hexpand            = true,
      column_homogeneous = true,
      margin_start       = 5,
      margin_end         = 5,
      margin_top         = 10,
      margin_bottom      = 5
    };

    egrid.attach( all,            0, 0 );
    egrid.attach( obox,           1, 0 );
    egrid.attach( for_import,     0, 1, 2 );
    egrid.attach( include_images, 0, 2, 2 );
    egrid.attach( bbox,           1, 3 );

    var frame_label  = new Label( Utils.make_title( _( "Export Options" ) ) ) {
      use_markup = true
    };
    var frame = new Frame( null ) {
      halign       = Align.FILL,
      hexpand      = true,
      label_xalign = (float)0.5,
      label_widget = frame_label,
      child        = egrid
    };

    return( frame );

  }

  /* Generates import UI for the Advanced panel */
  private Frame create_advanced_import() {

    var import_merge = new CheckButton.with_label( _( "Import entries into original journals, automatically creating non-existing journals" ) ) {
      active = true
    };

    var import_journal = new CheckButton.with_label( _( "Import all entries into journal" ) ) {
      group = import_merge
    };

    var journals_menu = new GLib.Menu();
    for( int i=0; i<_journals.num_journals(); i++ ) {
      var journal = _journals.get_journal( i );
      journals_menu.append( journal.name, "prefs.action_select_import_journal('%s')".printf( journal.name ) );
    }

    var new_menu = new GLib.Menu();
    new_menu.append( _( "Create new journal" ), "prefs.action_select_new_import_journal" );

    var journal_menu = new GLib.Menu();
    journal_menu.append_section( null, journals_menu );
    journal_menu.append_section( null, new_menu );

    _import_mb = new MenuButton() {
      label      = _journals.get_journal( 0 ).name,
      sensitive  = false,
      menu_model = journal_menu
    };

    import_merge.toggled.connect(() => {
      _win.reset_timer();
    });

    import_journal.toggled.connect(() => {
      _win.reset_timer();
      _import_mb.sensitive = import_journal.active;
    });

    _new_entry = new Entry() {
      placeholder_text = _( "Enter new journal name" )
    };
    _new_entry.hide();

    var jbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign  = Align.FILL,
      hexpand = true
    };
    jbox.append( import_journal );
    jbox.append( _import_mb );
    jbox.append( _new_entry );

    _import = new Button.with_label( "Import…" ) {
      halign  = Align.END,
      hexpand = true
    };
    _import.clicked.connect(() => {
      _win.reset_timer();
      do_import( import_merge.active ? "" :
                 _new_entry_shown ? _new_entry.text :
                 _import_mb.label );
    });

    _new_entry.changed.connect(() => {
      _win.reset_timer();
      _import.sensitive = (!_new_entry_shown || ((_new_entry.text != "") && (_journals.get_journal_by_name( _new_entry.text ) == null)));
    });

    var bbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign  = Align.FILL,
      hexpand = true
    };
    bbox.append( _import );

    var ibox = new Box( Orientation.VERTICAL, 5 ) {
      halign        = Align.FILL,
      hexpand       = true,
      margin_top    = 10,
      margin_bottom = 5,
      margin_start  = 5,
      margin_end    = 5
    };
    ibox.append( import_merge );
    ibox.append( jbox );
    ibox.append( bbox );

    var frame_label  = new Label( Utils.make_title( _( "Import Options" ) ) ) {
      use_markup = true
    };
    var frame = new Frame( null ) {
      halign       = Align.FILL,
      hexpand      = true,
      label_xalign = (float)0.5,
      label_widget = frame_label,
      child        = ibox
    };

    return( frame );

  }

  /* Selects the journal to export */
  private void action_select_journal_for_export( SimpleAction action, Variant? variant ) {

    _win.reset_timer();
    _journal_mb.label = variant.get_string();

  }

  /* Selects the export format */
  private void action_select_export_format( SimpleAction action, Variant? variant ) {

    _win.reset_timer();

    _format_name = variant.get_string();

    stdout.printf( "In action_select_export_format, format: %s\n", _format_name );

    var export = _win.exports.get_by_name( _format_name );
    _format_mb.label = export.label;

  }

  /* Performs the export based on the settings */
  private void do_export( string journal, bool for_import, bool include_images, string format ) {

    var journals = new Array<Journal>();
    if( journal == "" ) {
      for( int i=0; i<_journals.num_journals(); i++ ) {
        journals.append_val( _journals.get_journal( i ) );
      }
    } else {
      journals.append_val( _journals.get_journal_by_name( journal ) );
    }

    var export = _win.exports.get_by_name( format );
    export.include_images = include_images;

    if( format == "xml" ) {
      var xml_export = (ExportXML)export;
      xml_export.for_import = for_import;
    }

    var dialog = Utils.make_file_chooser( _( "Export Data As…" ), this, FileChooserAction.SAVE, _( "Export" ) );

    /* Add filters */
    var filter = new FileFilter() {
      name = export.label
    };
    foreach( var ext in export.extensions ) {
      filter.add_suffix( ext );
    }
    dialog.add_filter( filter );

    dialog.response.connect((id) => {
      _win.reset_timer();
      if( id == ResponseType.ACCEPT ) {
        var file = dialog.get_file();
        if( file != null ) {
          if( export.export( file.get_path() + (include_images ? ".bundle" : ""), journals ) ) {
            _win.notification( _( "Export successful" ), "" );
          } else {
            _win.notification( _( "Export failed" ), "" );
          }
        }
      }
      dialog.close();
    });

    dialog.show();

  }

  /* Called when the user selects an existing journal from the menu */
  private void action_select_import_journal( SimpleAction action, Variant? variant ) {

    _win.reset_timer();
    _import_mb.label = variant.get_string();
    _import.sensitive = true;
    _new_entry.hide();
    _new_entry_shown = false;

  }

  /* Prompts the user to create a new Journal */
  private void action_select_new_import_journal() {

    _win.reset_timer();
    _import_mb.label = _( "new called" );
    _import.sensitive = false;
    _new_entry.text = "";
    _new_entry.show();
    _new_entry.grab_focus();
    _new_entry_shown = true;

  }

  /* Handles the import of an XML file into either a new journal or merged into the existing journals */
  private void do_import( string journal_name ) {

    Journal journal = null;

    var export = (ExportXML)_win.exports.get_by_name( "xml" );

    if( journal_name != "" ) {
      journal = _journals.get_journal_by_name( journal_name );
      if( journal == null ) {
        journal = new Journal( journal_name, "", "" );
        _journals.add_journal( journal, true );
      }
    }

    var dialog = Utils.make_file_chooser( _( "Import Data From…" ), this, FileChooserAction.OPEN, _( "Import" ) );

    /* Add filters */
    var filter = new FileFilter() {
      name = export.label
    };
    foreach( var ext in export.extensions ) {
      filter.add_suffix( ext );
      filter.add_suffix( ext + ".bundle" );
    }
    dialog.add_filter( filter );

    dialog.response.connect((id) => {
      _win.reset_timer();
      if( id == ResponseType.ACCEPT ) {
        var file = dialog.get_file();
        if( file != null ) {
          if( export.import( file.get_path(), _journals, journal ) ) {
            _journals.current_changed( true );
            _win.notification( _( "Import successful" ), "" );
          } else {
            _win.notification( _( "Import failed" ), "" );
          }
        }
      }
      dialog.close();
    });

    dialog.show();

  }

  // -----------------------------------------------------------------

  /* Creates visual spacer */
  private Label make_spacer() {
    var w = new Label( "" );
    return( w );
  }

  /* Creates label */
  private Label make_label( string label ) {
    var w = new Label( Utils.make_title( label ) ) {
      use_markup = true,
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
    w.activate.connect( _win.reset_timer );
    Journaler.settings.bind( setting, w, "active", SettingsBindFlags.DEFAULT );
    return( w );
  }

  /* Creates spinner */
  private SpinButton make_spinner( string setting, int min_value, int max_value, int step ) {
    var w = new SpinButton.with_range( min_value, max_value, step );
    w.value_changed.connect( _win.reset_timer );
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
    w.changed.connect( _win.reset_timer );
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

  /* Creates a menubutton with the given menu */
  private MenuButton make_menu( string setting, string label, GLib.Menu menu ) {
    var w = new MenuButton() {
      label      = label,
      menu_model = menu
    };
    _menus.set( setting, w );
    return( w );
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
    _win.reset_timer();

  }

}
