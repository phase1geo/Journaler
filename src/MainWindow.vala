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

public class MainWindow : Gtk.ApplicationWindow {

  private const int _sidebar_width = 300;

  private GLib.Settings              _settings;
  private Stack                      _lock_stack;
  private TextArea                   _text_area;
  private Stack                      _sidebar_stack;
  private Journals                   _journals;
  private Templates                  _templates;
  private Templater                  _templater;
  private SidebarEntries             _entries;
  private SidebarEditor              _editor;
  private Gee.HashMap<string,Widget> _stack_focus_widgets;
  private GLib.Menu                  _templates_menu;

  // private UnicodeInsert   _unicoder;

  private const GLib.ActionEntry[] action_entries = {
    { "action_today",         action_today },
    { "action_save",          action_save },
    { "action_lock",          action_lock },
    { "action_quit",          action_quit },
    { "action_new_template",  action_new_template },
    { "action_edit_template", action_edit_template, "s" },
    { "action_shortcuts",     action_shortcuts },
    { "action_preferences",   action_preferences },
  };

  private bool on_elementary = Gtk.Settings.get_default().gtk_icon_theme_name == "elementary";

  public GLib.Settings settings {
    get {
      return( _settings );
    }
  }
  /*
  public UnicodeInsert unicoder {
    get {
      return( _unicoder );
    }
  }
  */

  public signal void dark_mode_changed( bool mode );

  /* Create the main window UI */
  public MainWindow( Gtk.Application app, GLib.Settings settings ) {

    Object( application: app );

    _settings = settings;

    /* Create and load the templates */
    _templates = new Templates();
    _templates.changed.connect((name, added) => {
      update_templates();
    });

    /* Create and load the journals */
    _journals = new Journals();

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
    header.pack_start( today_btn );

    /* Create gear menu */
    var misc_img = new Image.from_icon_name( get_header_icon_name( "emblem-system" ) );
    var misc_btn = new MenuButton() {
      has_frame  = false,
      child      = misc_img,
      menu_model = create_misc_menu() 
    };
    header.pack_end( misc_btn );

    /* Create lock */
    var lock_btn = new Button.from_icon_name( get_header_icon_name( "changes-prevent" ) );
    lock_btn.set_tooltip_markup( Utils.tooltip_with_accel( _( "Lock Journaler" ), "<Control>l" ) );
    lock_btn.clicked.connect( action_lock );
    header.pack_end( lock_btn );

    var lbox = new Box( Orientation.VERTICAL, 0 );
    var rbox = new Box( Orientation.VERTICAL, 0 );

    add_text_area( lbox );
    add_sidebar( rbox );

    var pw = new Paned( Orientation.HORIZONTAL ) {
      start_child        = lbox,
      end_child          = rbox,
      resize_start_child = true,
      resize_end_child   = false,
      shrink_start_child = true,
      shrink_end_child   = false
    };

    var sbox = new Box( Orientation.VERTICAL, 0 ) {
      halign  = Align.FILL,
      hexpand = true,
      valign  = Align.FILL,
      vexpand = true
    };

    add_setlock_view( sbox );

    var pbox = new Box( Orientation.VERTICAL, 0 ) {
      halign  = Align.FILL,
      hexpand = true,
      valign  = Align.FILL,
      vexpand = true
    };

    add_locked_view( pbox );

    var tbox = new Box( Orientation.VERTICAL, 0 ) {
      halign  = Align.FILL,
      hexpand = true,
      valign  = Align.FILL,
      vexpand = true
    };

    add_template_view( tbox );

    /* Create primary stack */
    _lock_stack = new Stack() {
      halign = Align.FILL,
      valign = Align.FILL,
      hexpand = true,
      vexpand = true
    };
    _lock_stack.add_named( pbox, "lock-view" );
    _lock_stack.add_named( pw,   "entry-view" );
    _lock_stack.add_named( sbox, "setlock-view" );
    _lock_stack.add_named( tbox, "template-view" );

    child = _lock_stack;

    show();

    dark_mode_changed.connect((mode) => {
      pbox.remove_css_class( mode ? "login-pane-light" : "login-pane-dark" );
      sbox.remove_css_class( mode ? "login-pane-light" : "login-pane-dark" );
      pbox.add_css_class( mode ? "login-pane-dark" : "login-pane-light" );
      sbox.add_css_class( mode ? "login-pane-dark" : "login-pane-light" );
    });

    /* If the user has set a password, show the journal as locked immediately */
    if( Security.does_password_exist() ) {
      show_pane( "lock-view", true );
    } else {
      show_pane( "entry-view", true );
    }

    /* Handle any request to close the window */
    close_request.connect(() => {
      action_save();
      return( false );
    });

    /* Loads the application-wide CSS */
    load_css();

    /* Load the available templates */
    _templates.load();

    /* Load the available journals */
    _journals.load();

    /* Make sure that we display today's entry */
    action_today();

  }

  /* Create the miscellaneous menu */
  private GLib.Menu create_misc_menu() {

    _templates_menu = new GLib.Menu();

    var new_template = new GLib.Menu();
    new_template.append( _( "Create New Template" ), "win.action_new_template" );

    var template_menu = new GLib.Menu();
    template_menu.append_section( null, _templates_menu );
    template_menu.append_section( null, new_template );

    var misc_menu = new GLib.Menu();
    misc_menu.append_submenu( _( "Manage Templates" ), template_menu );
    misc_menu.append( _( "Shortcut Cheatsheet" ), "win.action_shortcuts" );
    misc_menu.append( _( "Preferences…" ), "win.action_preferences" );

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

  /* Displays the given pane in the main window */
  public void show_pane( string name, bool on_start = false ) {

    /* Set the transition type */
    switch( name ) {
      case "entry-view" :
        if( _lock_stack.visible_child_name == "template-view" ) {
          _lock_stack.transition_type = StackTransitionType.SLIDE_LEFT;
        } else {
          _lock_stack.transition_type = StackTransitionType.SLIDE_UP;
        }
        get_titlebar().sensitive = true;
        break;
      case "template-view" :
        _lock_stack.transition_type = StackTransitionType.SLIDE_RIGHT;
        get_titlebar().sensitive = false;
        break;
      default :
        _lock_stack.transition_type = StackTransitionType.SLIDE_DOWN;
        get_titlebar().sensitive = false;
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
  private void add_text_area( Box box ) {

    _text_area = new TextArea( this, _journals, _templates );

    box.append( _text_area );

    _stack_focus_widgets.set( "entry-view", _text_area.get_focus_widget() );

  }

  /* Adds the sidebar */
  private void add_sidebar( Box box ) {

    _sidebar_stack = new Stack();
    _sidebar_stack.add_named( add_current_sidebar(), "entries" );
    _sidebar_stack.add_named( add_journal_edit(),    "editor" );

    box.append( _sidebar_stack );

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
    });

    var save = new Button.with_label( _( "Set Password" ) ) {
      halign = Align.END,
      sensitive = false
    };
    save.add_css_class( "suggested-action" );
    save.clicked.connect(() => {
      Security.create_password_file( entry2.text );
      show_pane( "entry-view" );
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
    grid.attach( lbl1,   0, 0 );
    grid.attach( entry1, 1, 0 );
    grid.attach( lbl2,   0, 1 );
    grid.attach( entry2, 1, 1 );
    grid.attach( bbox,   0, 2, 2 );

    box.append( grid );

    _stack_focus_widgets.set( "setlock-view", entry1 );

    dark_mode_changed.connect((mode) => {
      grid.remove_css_class( mode ? "login-frame-light" : "login-frame-dark" );
      grid.add_css_class( mode ? "login-frame-dark" : "login-frame-light" );
    });

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
    pbox.append( lbl );
    pbox.append( entry );

    box.append( pbox );

    _stack_focus_widgets.set( "lock-view", entry );

    dark_mode_changed.connect((mode) => {
      pbox.remove_css_class( mode ? "login-frame-light" : "login-frame-dark" );
      pbox.add_css_class( mode ? "login-frame-dark" : "login-frame-light" );
    });

  }

  /* Creates the template editor pane */
  private void add_template_view( Box box ) {

    _templater = new Templater( this, _templates );

    box.append( _templater );

    _stack_focus_widgets.set( "template-view", _templater.get_focus_widget() );

  }

  /* Edits the given template name.  If name is not specified, a new template will be created. */
  public void edit_template( string? name = null ) {

    _templater.set_current( name );
    show_pane( "template-view" );

  }

  /* Creates the current journal sidebar */
  private Box add_current_sidebar() {

    _entries = new SidebarEntries( this, _journals, _templates );

    _entries.edit_journal.connect((journal) => {
      _editor.edit_journal( journal );
      _sidebar_stack.visible_child_name = "editor";
    });

    _entries.show_journal_entry.connect((entry, editable) => {
      _text_area.set_buffer( entry, editable );
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

    app.set_accels_for_action( "win.action_today", { "<Control>t" } );
    app.set_accels_for_action( "win.action_save",  { "<Control>s" } );
    app.set_accels_for_action( "win.action_lock",  { "<Control>l" } );
    app.set_accels_for_action( "win.action_quit",  { "<Control>q" } );

  }

  /* Creates a new file */
  public void action_today() {
    _entries.show_entry_for_date( DBEntry.todays_date(), true );
  }

  /* Save the current entry to the database */
  public void action_save() {
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
    destroy();
  }

  /* Creates a new template */
  private void action_new_template() {
    edit_template();
  }

  /* Edits an existing template by the given name */
  private void action_edit_template( SimpleAction action, Variant? variant ) {
    edit_template( variant.get_string() );
  }

  /* Displays the shortcuts cheatsheet */
  private void action_shortcuts() {

    var builder = new Builder.from_resource( "/com/github/phase1geo/journaler/shortcuts.ui" );
    var win     = builder.get_object( "shortcuts" ) as ShortcutsWindow;

    win.transient_for = this;
    win.view_name     = null;

    /* Display the most relevant information based on the current state */
    /*
    if( da.is_node_editable() || da.is_connection_editable() ) {
      win.section_name = "text-editing";
    } else if( da.is_node_selected() ) {
      win.section_name = "node";
    } else if( da.is_connection_selected() ) {
      win.section_name = "connection";
    } else {
      win.section_name = "general";
    }
    */

    win.show();

  }

  private void action_preferences() {

    /* TBD */

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

