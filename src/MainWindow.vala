 /*
* Copyright (c) 2018 (https://github.com/phase1geo/Minder)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 2 of the License, or (at your option) any later version.
*
* This program is distributed in the hope that it will be useful,
* but WITHOUT ANY WARRANTY; without even the implied warranty of
* MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
* General Public License for more details.
*
* You should have received a copy of the GNU General Public
* License along with this program; if not, write to the
* Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
* Boston, MA 02110-1301 USA
*
* Authored by: Trevor Williams <phase1geo@gmail.com>
*/

using Gtk;
using Gdk;

public enum AutoLockOption {
  NEVER,
  AFTER_1_MIN,
  AFTER_2_MIN,
  AFTER_5_MIN,
  AFTER_10_MIN,
  AFTER_15_MIN,
  AFTER_30_MIN,
  AFTER_1_HOUR,
  ON_SCREENSAVER,
  ON_APP_BACKGROUND,
  NUM;

  /* Returns the user-facing string value to display */
  public string label() {
    switch( this ) {
      case NEVER             :  return( _( "Never" ) );
      case AFTER_1_MIN       :  return( _( "After 1 minute of inactivity" ) );
      case AFTER_2_MIN       :  return( _( "After %d minutes of inactivity" ).printf( 2 ) );
      case AFTER_5_MIN       :  return( _( "After %d minutes of inactivity" ).printf( 5 ) );
      case AFTER_10_MIN      :  return( _( "After %d minutes of inactivity" ).printf( 10 ) );
      case AFTER_15_MIN      :  return( _( "After %d minutes of inactivity" ).printf( 15 ) );
      case AFTER_30_MIN      :  return( _( "After %d minutes of inactivity" ).printf( 30 ) );
      case AFTER_1_HOUR      :  return( _( "After 1 hour of inactivity" ) );
      case ON_SCREENSAVER    :  return( _( "When screensaver is invoked" ) );
      case ON_APP_BACKGROUND :  return( _( "When application loses focus" ) );
      default                :  assert_not_reached();
    }
  }

  /* Returns true if we should start adding this option and subsequence to a new menu */
  public bool new_menu() {
    return( (this == NEVER) || (this == AFTER_1_MIN) || (this == ON_SCREENSAVER) );
  }

  /* Parses the integer value and converts it to this type */
  public static AutoLockOption parse( uint value ) {
    if( value >= (uint)NUM ) {
      return( NEVER );
    } else {
      return( (AutoLockOption)value );
    }
  }

  /* Returns the number of minutes of inactivity before the application is locked */
  public int minutes() {
    switch( this ) {
      case AFTER_1_MIN  :  return( 1 );
      case AFTER_2_MIN  :  return( 2 );
      case AFTER_5_MIN  :  return( 5 );
      case AFTER_10_MIN :  return( 10 );
      case AFTER_15_MIN :  return( 15 );
      case AFTER_30_MIN :  return( 30 );
      case AFTER_1_HOUR :  return( 60 );
      default           :  return( 0 );
    }
  }

}

public class MainWindow : Gtk.ApplicationWindow {

  private const int _sidebar_width = 300;

  private GLib.Settings              _settings;
  private Stack                      _lock_stack;
  private TextArea                   _text_area;
  private Stack                      _sidebar_stack;
  private Revealer                   _sidebar_revealer;
  private Journals                   _journals;
  private Templates                  _templates;
  private Templater                  _templater;
  private SidebarEntries             _entries;
  private SidebarEditor              _editor;
  private Gee.HashMap<string,Widget> _stack_focus_widgets;
  private GLib.Menu                  _templates_menu;
  private List<Widget>               _header_buttons;
  private Themes                     _themes;
  private AutoLockOption             _auto_lock    = AutoLockOption.NEVER;
  private uint                       _auto_lock_id = 0;
  private Preferences                _prefs = null;
  private ShortcutsWindow            _shortcuts = null;
  private Exports                    _exports;
  private Goals                      _goals;
  private FlowBox                    _awards_box;
  private Label                      _awards_status;
  private Locker                     _locker;
  private Revealer                   _reviewer_revealer;
  private Reviewer                   _reviewer;

  private const GLib.ActionEntry[] action_entries = {
    { "action_today",               action_today },
    { "action_save",                action_save },
    { "action_lock",                action_lock },
    { "action_quit",                action_quit },
    { "action_new_template",        action_new_template },
    { "action_edit_template",       action_edit_template, "s" },
    { "action_review",              action_review },
    { "action_awards",              action_awards },
    { "action_shortcuts",           action_shortcuts },
    { "action_preferences",         action_preferences },
    { "action_toggle_distract",     action_toggle_distract },
    { "action_escape",              action_escape },
    { "action_show_previous_entry", action_show_previous_entry },
    { "action_show_next_entry",     action_show_next_entry },
  };

  private bool on_elementary = Gtk.Settings.get_default().gtk_icon_theme_name == "elementary";

  public GLib.Settings settings {
    get {
      return( _settings );
    }
  }
  public Themes themes {
    get {
      return( _themes );
    }
  }
  public Templates templates {
    get {
      return( _templates );
    }
  }
  public Exports exports {
    get {
      return( _exports );
    }
  }
  public bool locked {
    get {
      return( (_lock_stack.visible_child_name == "setlock-view") ||
              (_lock_stack.visible_child_name == "lock-view") );
    }
  }
  public Locker locker {
    get {
      return( _locker );
    }
  }
  public Goals goals {
    get {
      return( _goals );
    }
  }
  public bool review_mode           { get; set; default = false; }
  public bool distraction_free_mode { get; set; default = false; }

  /* Create the main window UI */
  public MainWindow( Gtk.Application app, GLib.Settings settings ) {

    Object( application: app );

    _settings = settings;
    _header_buttons = new List<Widget>();

    /* Load the available themes */
    _themes = new Themes();

    /* Add the exporters */
    _exports = new Exports();

    /* Create and load the templates */
    _templates = new Templates();
    _templates.changed.connect((name, added) => {
      update_templates();
    });

    /* Create and load the journals */
    _journals = new Journals( _templates );

    /* Creates the goals */
    _goals = new Goals( this );

    /* Creates the locker */
    _locker = new Locker( this );

    /* Create the hash map for the focus widgets */
    _stack_focus_widgets = new Gee.HashMap<string,Widget>();

    // var window_x = settings.get_int( "window-x" );
    // var window_y = settings.get_int( "window-y" );
    var window_w = settings.get_int( "window-w" );
    var window_h = settings.get_int( "window-h" );

    /* Create the header bar */
    var header = new HeaderBar() {
      show_title_buttons = true,
      title_widget = new Gtk.Label( _( "Journaler" ) )
    };
    set_titlebar( header );

    /* Set the main window data */
    set_default_size( window_w, window_h );

    /* Set the stage for menu actions */
    var actions = new SimpleActionGroup ();
    actions.add_action_entries( action_entries, this );
    insert_action_group( "win", actions );

    /* Add keyboard shortcuts */
    add_keyboard_shortcuts( app );

    /* Create title toolbar */
    var today_img = new Image.from_resource( "/com/github/phase1geo/journaler/today.svg" );
    var today_btn = new Button() {
      has_frame = false,
      child = today_img
    };
    today_btn.set_tooltip_markup( Utils.tooltip_with_accel( _( "Go To Today" ), "<Control>t" ) );
    today_btn.clicked.connect( action_today );
    _header_buttons.append( today_btn );
    header.pack_start( today_btn );

    /* Create gear menu */
    var misc_img = new Image.from_icon_name( get_header_icon_name( "emblem-system" ) );
    var misc_btn = new MenuButton() {
      has_frame  = false,
      child      = misc_img,
      menu_model = create_misc_menu() 
    };
    _header_buttons.append( misc_btn );
    header.pack_end( misc_btn );

    /* Create review button */
    var review_btn = new Button.from_icon_name( get_header_icon_name( "media-seek-backward" ) );
    review_btn.set_tooltip_markup( Utils.tooltip_with_accel( _( "Review Entries" ), "<Control>r" ) );
    review_btn.clicked.connect( action_review );
    _header_buttons.append( review_btn );
    header.pack_end( review_btn );

    /* Create lock */
    var lock_btn = new Button.from_icon_name( get_header_icon_name( "changes-prevent" ) );
    lock_btn.set_tooltip_markup( Utils.tooltip_with_accel( _( "Lock Journaler" ), "<Control>l" ) );
    lock_btn.clicked.connect( action_lock );
    _header_buttons.append( lock_btn );
    header.pack_end( lock_btn );

    /* Create the reviewer UI */
    _reviewer = new Reviewer( this, _journals );
    _reviewer.show_matched_entry.connect((entry, pos) => {
      _journals.current = entry.trash ? _journals.trash : _journals.get_journal_by_name( entry.journal );
      _entries.show_entry_for_date( entry.journal, entry.date, false, false, pos, "from show_matched_entry" );
    });
    _reviewer.close_requested.connect( action_review );

    _reviewer_revealer = new Revealer() {
      reveal_child = false,
      child        = _reviewer
    };

    var lbox = new Box( Orientation.VERTICAL, 0 );
    var rbox = new Box( Orientation.VERTICAL, 0 );

    add_text_area( app, lbox );
    add_sidebar( rbox );

    var pw = new Paned( Orientation.HORIZONTAL ) {
      start_child        = lbox,
      end_child          = rbox,
      resize_start_child = true,
      resize_end_child   = false,
      shrink_start_child = true,
      shrink_end_child   = false
    };

    var ebox = new Box( Orientation.VERTICAL, 0 ) {
      halign  = Align.FILL,
      valign  = Align.FILL,
      vexpand = true,
      hexpand = true
    };
    ebox.append( _reviewer_revealer );
    ebox.append( pw );

    var sbox = new Box( Orientation.VERTICAL, 0 ) {
      halign  = Align.FILL,
      hexpand = true,
      valign  = Align.FILL,
      vexpand = true
    };

    add_setlock_view( sbox );
    locker.add_widget( sbox );

    var pbox = new Box( Orientation.VERTICAL, 0 ) {
      halign  = Align.FILL,
      hexpand = true,
      valign  = Align.FILL,
      vexpand = true
    };

    add_locked_view( pbox );
    locker.add_widget( pbox );

    var tbox = new Box( Orientation.VERTICAL, 0 ) {
      halign  = Align.FILL,
      hexpand = true,
      valign  = Align.FILL,
      vexpand = true
    };

    add_template_view( app, tbox );

    var abox = new Box( Orientation.VERTICAL, 0 ) {
      halign        = Align.FILL,
      valign        = Align.FILL,
      hexpand       = true,
      vexpand       = true,
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };

    add_awards_view( abox );

    var ibox = _text_area.image_area.create_full_image_viewer();
    _stack_focus_widgets.set( "image-view", _text_area.image_area.get_focus_widget() );

    /* Create primary stack */
    _lock_stack = new Stack() {
      halign = Align.FILL,
      valign = Align.FILL,
      hexpand = true,
      vexpand = true
    };
    _lock_stack.add_named( pbox, "lock-view" );
    _lock_stack.add_named( ebox, "entry-view" );
    _lock_stack.add_named( sbox, "setlock-view" );
    _lock_stack.add_named( tbox, "template-view" );
    _lock_stack.add_named( abox, "awards-view" );
    _lock_stack.add_named( ibox, "image-view" );

    child = _lock_stack;

    show();

    /*
    _themes.theme_changed.connect((name) => {
      pbox.remove_css_class( _themes.dark_mode ? "login-pane-light" : "login-pane-dark" );
      sbox.remove_css_class( _themes.dark_mode ? "login-pane-light" : "login-pane-dark" );
      pbox.add_css_class( _themes.dark_mode ? "login-pane-dark" : "login-pane-light" );
      sbox.add_css_class( _themes.dark_mode ? "login-pane-dark" : "login-pane-light" );
    });
    */

    /* If the user has set a password, show the journal as locked immediately */
    if( Security.does_password_exist() ) {
      show_pane( "lock-view", true );
      _auto_lock = (AutoLockOption)settings.get_int( "auto-lock" );
      reset_timer();
    } else {
      show_pane( "entry-view", true );
    }

    /* Handle any request to close the window */
    close_request.connect(() => {
      action_save();
      return( false );
    });

    /* If the auto-lock settings change, grab the value and reset the timer */
    settings.changed["auto-lock"].connect(() => {
      if( Security.does_password_exist() ) {
        _auto_lock = (AutoLockOption)settings.get_int( "auto-lock" );
      }
      reset_timer();
    });

    /* Loads the application-wide CSS */
    load_css();

    /* Load the available templates */
    _templates.load();

    /* Load the available journals */
    _journals.load();

    /* Load the goals */
    _goals.load();

    /* Make sure that we display today's entry */
    action_today();

  }

  /*
   This should be called for any user interactions with the UI.  This will cause the auto-lock
   timer to be reset.
  */
  public void reset_timer() {

    // stdout.printf( "In reset_timer\n" );

    /* Clear the counter and the timer */
    if( _auto_lock_id > 0 ) {
      Source.remove( _auto_lock_id );
    }

    if( _auto_lock == AutoLockOption.NEVER ) return;

    /* Set the timer */
    switch( _auto_lock ) {
      case AutoLockOption.ON_SCREENSAVER :
        _auto_lock_id = Timeout.add_seconds( 1, () => {
          if( application.screensaver_active ) {
            _auto_lock_id = 0;
            show_pane( "lock-view" );
            return( false );
          }
          return( true );
        });
        break;
      case AutoLockOption.ON_APP_BACKGROUND :
        _auto_lock_id = Timeout.add_seconds( 1, () => {
          if( !is_active && ((_prefs == null) || !_prefs.is_active) && ((_shortcuts == null) || !_shortcuts.is_active) ) {
            _auto_lock_id = 0;
            show_pane( "lock-view" );
            return( false );
          }
          return( true );
        });
        break;
      default :
        _auto_lock_id = Timeout.add_seconds( (60 * _auto_lock.minutes()), () => {
          _auto_lock_id = 0;
          show_pane( "lock-view" );
          return( false );
        });
        break;
    }

  }

  /* Create the miscellaneous menu */
  private GLib.Menu create_misc_menu() {

    _templates_menu = new GLib.Menu();

    var new_template = new GLib.Menu();
    new_template.append( _( "Create New Template" ), "win.action_new_template" );

    var template_menu = new GLib.Menu();
    template_menu.append_section( null, _templates_menu );
    template_menu.append_section( null, new_template );

    var award_menu = new GLib.Menu();
    award_menu.append( _( "View Awards" ), "win.action_awards" );

    var pref_menu = new GLib.Menu();
    pref_menu.append( _( "Shortcut Cheatsheet" ), "win.action_shortcuts" );
    pref_menu.append( _( "Preferences…" ), "win.action_preferences" );

    var misc_menu = new GLib.Menu();
    misc_menu.append_submenu( _( "Manage Templates" ), template_menu );
    misc_menu.append_section( null, award_menu );
    misc_menu.append_section( null, pref_menu );

    return( misc_menu );

  }

  /* Updates the templates to manage */
  private void update_templates() {
    _templates_menu.remove_all();
    foreach( var template in _templates.templates ) {
      _templates_menu.append( template.name, "win.action_edit_template('%s')".printf( template.name ) );
    }
  }

  /* Returns the currently visibile lock stack pane */
  public string get_current_pane() {
    return( _lock_stack.visible_child_name );
  }

  /* Sets the sensitivity of all header bar buttons placed by the application to the given value */
  private void set_header_bar_sensitivity( bool sensitive ) {
    foreach( var btn in _header_buttons ) {
      btn.sensitive = sensitive;
    }
  }

  /* Displays the given pane in the main window */
  public void show_pane( string name, bool on_start = false ) {

    /* Set the transition type */
    switch( name ) {
      case "entry-view" :
        if( _lock_stack.visible_child_name == "template-view" ) {
          _lock_stack.transition_type = StackTransitionType.SLIDE_LEFT;
        } else if( _lock_stack.visible_child_name == "awards-view" ) {
          _lock_stack.transition_type = StackTransitionType.CROSSFADE;
        } else if( _lock_stack.visible_child_name == "image-view" ) {
          _lock_stack.transition_type = StackTransitionType.SLIDE_DOWN;
        } else {
          _lock_stack.transition_type = StackTransitionType.SLIDE_UP;
        }
        set_header_bar_sensitivity( true );
        break;
      case "template-view" :
        _lock_stack.transition_type = StackTransitionType.SLIDE_RIGHT;
        set_header_bar_sensitivity( false );
        break;
      case "awards-view" :
        _lock_stack.transition_type = StackTransitionType.CROSSFADE;
        set_header_bar_sensitivity( false );
        break;
      case "image-view" :
        _lock_stack.transition_type = StackTransitionType.SLIDE_UP;
        set_header_bar_sensitivity( false );
        break;
      default :
        if( _prefs != null ) {
          _prefs.close();
        }
        if( _shortcuts != null ) {
          _shortcuts.close();
        }
        _lock_stack.transition_type = StackTransitionType.SLIDE_DOWN;
        set_header_bar_sensitivity( false );
        break;
    }

    if( on_start ) {
      _lock_stack.transition_type = StackTransitionType.NONE;
    }

    /* Perform the transition */
    _lock_stack.visible_child_name = name;

    /* Make sure that the proper widget is given the focus */
    Idle.add(() => {
      _stack_focus_widgets.get( name ).grab_focus();
      return( false );
    });

  }

  /* Creates the textbox with today's entry. */
  private void add_text_area( Gtk.Application app, Box box ) {

    _text_area = new TextArea( app, this, _journals, _templates );

    box.append( _text_area );

    _stack_focus_widgets.set( "entry-view", _text_area.get_focus_widget() );

  }

  /* Adds the sidebar */
  private void add_sidebar( Box box ) {

    _sidebar_stack = new Stack();
    _sidebar_stack.add_named( add_current_sidebar(), "entries" );
    _sidebar_stack.add_named( add_journal_edit(),    "editor" );
    _sidebar_stack.add_named( _reviewer.create_reviewer_match_sidebar(), "review" );

    _sidebar_revealer = new Revealer() {
      child = _sidebar_stack,
      transition_type = RevealerTransitionType.SLIDE_LEFT,
      reveal_child = true
    };

    box.append( _sidebar_revealer );

  }

  /* Create the setlock view panel */
  private void add_setlock_view( Box box ) {

    var lbl1 = new Label( Utils.make_title( "Enter Lock Password:" ) ) {
      xalign = (float)1.0,
      use_markup = true
    };
    var lbl2 = new Label( Utils.make_title( "Confirm Lock Password:" ) ) {
      xalign = (float)1.0,
      use_markup = true
    };
    var entry1 = new Entry() {
      input_hints   = InputHints.PRIVATE,
      input_purpose = InputPurpose.PASSWORD,
      visibility    = false
    };
    var entry2 = new Entry() {
      input_hints   = InputHints.PRIVATE,
      input_purpose = InputPurpose.PASSWORD,
      visibility    = false,
      sensitive     = false
    };

    var cancel = new Button.with_label( _( "Cancel" ) ) {
      halign = Align.START
    };
    cancel.clicked.connect(() => {
      show_pane( "entry-view" );
      reset_timer();
    });

    var save = new Button.with_label( _( "Set Password" ) ) {
      halign = Align.END,
      sensitive = false
    };
    save.add_css_class( "suggested-action" );
    save.clicked.connect(() => {
      Security.create_password_file( entry2.text );
      show_pane( "entry-view" );
      reset_timer();
    });

    var bbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign = Align.END,
      hexpand = true
    };
    bbox.append( cancel );
    bbox.append( save );

    entry1.changed.connect(() => {
      entry2.text = "";
      entry2.sensitive = (entry1.text != "");
    });
    entry1.activate.connect(() => {
      entry2.grab_focus();
    });

    entry2.changed.connect(() => {
      save.sensitive = (entry1.text == entry2.text);
    });
    entry2.activate.connect(() => {
      if( save.sensitive ) {
        save.clicked();
      } else {
        entry2.add_css_class( "password-invalid" );
        Timeout.add( 200, () => {
          entry2.remove_css_class( "password-invalid" );
          entry2.text = "";
          return( false );
        });
      }
    });

    var grid = new Grid() {
      row_spacing    = 5,
      column_spacing = 5,
      halign         = Align.CENTER,
      valign         = Align.CENTER,
      vexpand        = true
    };
    grid.add_css_class( "login-frame" );
    grid.add_css_class( Granite.STYLE_CLASS_BACKGROUND );
    grid.attach( lbl1,   0, 0 );
    grid.attach( entry1, 1, 0 );
    grid.attach( lbl2,   0, 1 );
    grid.attach( entry2, 1, 1 );
    grid.attach( bbox,   0, 2, 2 );

    box.append( grid );

    _stack_focus_widgets.set( "setlock-view", entry1 );

    /*
    _themes.theme_changed.connect((name) => {
      grid.remove_css_class( _themes.dark_mode ? "login-frame-light" : "login-frame-dark" );
      grid.add_css_class( _themes.dark_mode ? "login-frame-dark" : "login-frame-light" );
    });
    */

  }

  /* Displays the locked view pane */
  private void add_locked_view( Box box ) {

    var lbl = new Label( Utils.make_title( "Password:" ) ) {
      use_markup = true
    };
    var entry = new Entry() {
      visibility    = false,
      input_purpose = InputPurpose.PASSWORD,
      input_hints   = InputHints.PRIVATE
    };
    entry.activate.connect(() => {
      if( Security.does_password_match( entry.text ) ) {
        show_pane( "entry-view" );
        reset_timer();
      } else {
        entry.add_css_class( "password-invalid" );
      }
      Timeout.add( 200, () => {
        entry.text = "";
        entry.remove_css_class( "password-invalid" );
        return( false );
      });
    });

    var pbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign = Align.CENTER,
      valign = Align.CENTER,
      vexpand = true
    };
    pbox.add_css_class( "login-frame" );
    pbox.add_css_class( Granite.STYLE_CLASS_BACKGROUND );
    pbox.append( lbl );
    pbox.append( entry );

    box.append( pbox );

    _stack_focus_widgets.set( "lock-view", entry );

  }

  /* Creates the template editor pane */
  private void add_template_view( Gtk.Application app, Box box ) {

    _templater = new Templater( app, this, _text_area.image_area, _templates );

    box.append( _templater );

    _stack_focus_widgets.set( "template-view", _templater.get_focus_widget() );

  }

  /* Edits the given template name.  If name is not specified, a new template will be created. */
  public void edit_template( string? name = null ) {

    _templater.set_current( name );
    show_pane( "template-view" );

  }

  /* Create the rewards view */
  private void add_awards_view( Box box ) {

    _awards_box = new FlowBox() {
      row_spacing    = 5,
      column_spacing = 5,
      halign         = Align.FILL,
      valign         = Align.FILL,
      hexpand        = true,
      vexpand        = true,
      homogeneous    = true,
    };

    var scroll = new ScrolledWindow() {
      child = _awards_box
    };

    var bbox = new Box( Orientation.HORIZONTAL, 0 ) {
      halign  = Align.FILL,
      hexpand = true
    };

    _awards_status = new Label( "" ) {
      halign  = Align.START,
      hexpand = true
    };

    var close = new Button.with_label( _( "Close" ) ) {
      halign  = Align.END,
      hexpand = true
    };
    close.clicked.connect(() => {
      reset_timer();
      show_pane( "entry-view" );
    });

    bbox.append( _awards_status );
    bbox.append( close );

    box.append( scroll );
    box.append( bbox );

    _stack_focus_widgets.set( "awards-view", close );

  }

  /* Creates the current journal sidebar */
  private Box add_current_sidebar() {

    _entries = new SidebarEntries( this, _text_area, _journals, _templates );

    _entries.edit_journal.connect((journal) => {
      _editor.edit_journal( journal );
      _sidebar_stack.visible_child_name = "editor";
    });

    _entries.show_journal_entry.connect((entry, editable, pos) => {
      _text_area.set_buffer( entry, editable, pos );
    });

    return( _entries );

  }

  /* Adds the journal editor to the sidebar */
  private Box add_journal_edit() {

    _editor = new SidebarEditor( this, _journals, _templates );

    _editor.done.connect(() => {
      _sidebar_stack.visible_child_name = "entries";
    });

    return( _editor );

  }

  /* Loads the application-wide CSS */
  private void load_css() {

    var provider = new CssProvider();
    provider.load_from_resource( "/com/github/phase1geo/journaler/Application.css" );
    StyleContext.add_provider_for_display( get_display(), provider, STYLE_PROVIDER_PRIORITY_APPLICATION );

  }

  /* Returns the name of the icon to use for a headerbar icon */
  private string get_header_icon_name( string icon_name ) {
    return( "%s%s".printf( icon_name, (on_elementary ? "" : "-symbolic") ) );
  }

  /* Adds keyboard shortcuts for the menu actions */
  private void add_keyboard_shortcuts( Gtk.Application app ) {

    app.set_accels_for_action( "win.action_today",               { "<Control>t" } );
    app.set_accels_for_action( "win.action_save",                { "<Control>s" } );
    app.set_accels_for_action( "win.action_lock",                { "<Control>l" } );
    app.set_accels_for_action( "win.action_quit",                { "<Control>q" } );
    app.set_accels_for_action( "win.action_review",              { "<Control>r" } );
    app.set_accels_for_action( "win.action_awards",              { "<Control>g" } );
    app.set_accels_for_action( "win.action_shortcuts",           { "<Control>question" } );
    app.set_accels_for_action( "win.action_preferences",         { "<Control>comma" } );
    app.set_accels_for_action( "win.action_toggle_distract",     { "<Control>d" } );
    app.set_accels_for_action( "win.action_escape",              { "Escape" } );
    app.set_accels_for_action( "win.action_show_previous_entry", { "<Control>Left" } );
    app.set_accels_for_action( "win.action_show_next_entry",     { "<Control>Right" } );

  }

  /* Creates a new file */
  public void action_today() {

    reset_timer();
    if( locked ) return;

    if( review_mode ) {
      action_review();
    } else {
      _entries.show_entry_for_date( _journals.current.name, DBEntry.todays_date(), true, true, SelectedEntryPos.OTHER, "action_today" );
    }

  }

  /* Save the current entry to the database */
  public void action_save() {
    reset_timer();
    if( locked ) return;
    _text_area.save();
  }

  /* Locks the application */
  public void action_lock() {
    if( Security.does_password_exist() ) {
      show_pane( "lock-view" );
    } else {
      show_pane( "setlock-view" );
    }
  }

  /* Called when the user uses the Control-q keyboard shortcut */
  private void action_quit() {
    unfullscreen();
    Timeout.add(100, () => {
      if( is_fullscreen() ) {
        return( true );
      }
      destroy();
      return( false );
    });
  }

  /* Creates a new template */
  private void action_new_template() {
    reset_timer();
    edit_template();
  }

  /* Edits an existing template by the given name */
  private void action_edit_template( SimpleAction action, Variant? variant ) {
    reset_timer();
    edit_template( variant.get_string() );
  }

  /* Refreshes the awards view */
  private void refresh_awards() {

    FlowBoxChild? w = null;

    _awards_status.label = _goals.get_achievement_status();

    do {
      w = _awards_box.get_child_at_index( 0 );
      if( w != null ) {
        _awards_box.remove( w.child );
      }
    } while( w != null );

    for( int i=0; i<_goals.size(); i++ ) {

      Picture img;
      var goal = _goals.index( i );

      /* Create image icon */
      if( goal.achieved ) {
        img = new Picture.for_resource( "/com/github/phase1geo/journaler/award-achieved.png" );
      } else {
        img = new Picture.for_resource( "/com/github/phase1geo/journaler/award-unachieved.png" );
      }

      var lbl1 = new Label( Utils.make_title( goal.label ) ) {
        use_markup = true,
        halign     = Align.START
      };

      var status = goal.achieved ?
                   _( "Complete!" ) :
                   _( "%d out of %d (%d%%)" ).printf( goal.count, goal.goal, goal.completion_percentage() );

      var lbl2 = new Label( _( "Status: %s" ).printf( status ) ) {
        halign = Align.START
      };

      var vbox = new Box( Orientation.VERTICAL, 5 ) {
        valign  = Align.CENTER,
        vexpand = true,
      };
      vbox.append( lbl1 );
      vbox.append( lbl2 );

      var hbox = new Box( Orientation.HORIZONTAL, 5 ) {
        valign        = Align.FILL,
        vexpand       = true,
        margin_start  = 5,
        margin_end    = 5,
        margin_top    = 5,
        margin_bottom = 5
      };
      hbox.append( img );
      hbox.append( vbox );

      _awards_box.append( hbox );

    }

  }

  /* Displays the review view */
  private void action_review() {

    reset_timer();
    if( locked ) return;

    /* If we are in distraction-free mode, switch back */
    if( distraction_free_mode ) {
      action_toggle_distract();
    }

    if( review_mode ) {
      review_mode = false;
      _reviewer.on_close();
      _reviewer_revealer.reveal_child = false;
      _sidebar_stack.visible_child_name = "entries";
      _text_area.set_buffer( null, true, SelectedEntryPos.OTHER );
      _entries.last_editable = true;
    } else {
      review_mode = true;
      _reviewer.initialize();
      _reviewer_revealer.reveal_child = true;
      _sidebar_stack.visible_child_name = "review";
    }

  }

  /* Shows the awards view */
  private void action_awards() {

    reset_timer();
    if( locked ) return;

    refresh_awards();
    show_pane( "awards-view" );

  }

  /* Displays the shortcuts cheatsheet */
  private void action_shortcuts() {

    reset_timer();
    if( locked ) return;

    var builder = new Builder.from_resource( "/com/github/phase1geo/journaler/shortcuts.ui" );
    _shortcuts = builder.get_object( "shortcuts" ) as ShortcutsWindow;

    _shortcuts.transient_for = this;
    _shortcuts.view_name     = null;
    _shortcuts.show();

    _shortcuts.close_request.connect(() => {
      _shortcuts = null;
      return( false );
    });

  }

  /* Displays the preferences window and then handles its closing */
  private void action_preferences() {

    reset_timer();
    if( locked ) return;

    _prefs = new Preferences( this, _journals );
    _prefs.show();

    _prefs.close_request.connect(() => {
      Idle.add(() => {
        if( is_active ) {
          _prefs = null;
          return( false );
        }
        return( true );
      });
      return( false );
    });

  }

  /* Toggles distraction-free modes in edit and review modes */
  private void action_toggle_distract() {

    reset_timer();

    distraction_free_mode = !distraction_free_mode;

    if( _lock_stack.visible_child_name == "entry-view" ) {

      if( review_mode ) {
        if( distraction_free_mode ) {
          _reviewer_revealer.hide();
        } else {
          _reviewer_revealer.show();
        }
      } else {
        // Toggle entry
      }

      // Toggle the sidebar (regardless of mode)
      _text_area.set_distraction_free_mode( distraction_free_mode );

      if( distraction_free_mode ) {
        get_titlebar().hide();
        _sidebar_revealer.hide();
        fullscreen();
      } else {
        get_titlebar().show();
        _sidebar_revealer.show();
        unfullscreen();
      }

    }

  }

  /* Handles a press of the escape key */
  private void action_escape() {

    reset_timer();

    if( distraction_free_mode ) {
      action_toggle_distract();
    } else if( !locked ) {
      show_pane( "entry-view" );
    }

  }

  /* Shows the previous entry in review mode */
  private void action_show_previous_entry() {
    reset_timer();
    if( review_mode ) {
      _reviewer.show_previous_entry();
    }
  }

  /* Shows the next entry in review mode */
  private void action_show_next_entry() {
    reset_timer();
    if( review_mode ) {
      _reviewer.show_next_entry();
    }
  }

  /* Generate a notification */
  public void notification( string title, string msg, NotificationPriority priority = NotificationPriority.NORMAL ) {
    GLib.Application? app = null;
    @get( "application", ref app );
    if( app != null ) {
      var notification = new Notification( title );
      notification.set_body( msg );
      notification.set_priority( priority );
      app.send_notification( "com.github.phase1geo.minder", notification );
    }
  }

}

