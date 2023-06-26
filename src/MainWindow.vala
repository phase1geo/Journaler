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

  private GLib.Settings  _settings;
  private Stack          _lock_stack;
  private TextArea       _text_area;
  private Stack          _sidebar_stack;
  private Journals       _journals;
  private SidebarEntries _entries;
  private SidebarEditor  _editor;

  // private UnicodeInsert   _unicoder;

  private const GLib.ActionEntry[] action_entries = {
    { "action_today", action_today },
    { "action_save",  action_save },
    { "action_lock",  action_lock },
    { "action_quit",  action_quit },
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

  /* Create the main window UI */
  public MainWindow( Gtk.Application app, GLib.Settings settings ) {

    Object( application: app );

    _settings = settings;

    /* Create and load the journals */
    _journals = new Journals();

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
      child = today_img
    };
    today_btn.set_tooltip_markup( Utils.tooltip_with_accel( _( "Go To Today" ), "<Control>t" ) );
    today_btn.clicked.connect( action_today );
    header.pack_start( today_btn );

    /* Create lock */
    var lock_btn = new Button.from_icon_name( "changes-prevent" );
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

    /* Create primary stack */
    _lock_stack = new Stack() {
      halign = Align.FILL,
      valign = Align.FILL,
      hexpand = true,
      vexpand = true
    };
    _lock_stack.add_named( sbox, "setlock-view" );
    _lock_stack.add_named( pbox, "lock-view" );
    _lock_stack.add_named( pw,   "entry-view" );

    child = _lock_stack;

    show();

    /* If the user has set a password, show the journal as locked immediately */
    if( Security.does_password_exist() ) {
      _lock_stack.visible_child_name = "lock-view";
    } else {
      _lock_stack.visible_child_name = "entry-view";
    }

    /* Handle any request to close the window */
    close_request.connect(() => {
      action_save();
      return( false );
    });

    /* Loads the application-wide CSS */
    load_css();

    /* Load the available journals */
    _journals.load();

    /* Make sure that we display today's entry */
    action_today();

  }

  /* Creates the textbox with today's entry. */
  private void add_text_area( Box box ) {

    _text_area = new TextArea( this, _journals );

    box.append( _text_area );

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
      _lock_stack.visible_child_name = "entry-view";
    });

    var save = new Button.with_label( _( "Set Password" ) ) {
      halign = Align.END,
      sensitive = false
    };
    save.add_css_class( "suggested-action" );
    save.clicked.connect(() => {
      Security.create_password_file( entry2.text );
      _lock_stack.visible_child_name = "entry-view";
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

    entry2.changed.connect(() => {
      save.sensitive = (entry1.text == entry2.text);
    });
    entry2.activate.connect(() => {
      if( save.sensitive ) {
        save.clicked();
      }
    });

    var grid = new Grid() {
      row_spacing    = 5,
      column_spacing = 5,
      halign         = Align.CENTER,
      valign         = Align.CENTER
    };
    grid.attach( lbl1,   0, 0 );
    grid.attach( entry1, 1, 0 );
    grid.attach( lbl2,   0, 1 );
    grid.attach( entry2, 1, 1 );
    grid.attach( bbox,   0, 2, 2 );

    box.append( grid );

  }

  /* Displays the locked view pane */
  private void add_locked_view( Box box ) {

    var lbl = new Label( "Password:" );
    var entry = new Entry() {
      visibility    = false,
      input_purpose = InputPurpose.PASSWORD,
      input_hints   = InputHints.PRIVATE
    };
    entry.activate.connect(() => {
      if( Security.does_password_match( entry.text ) ) {
        _lock_stack.visible_child_name = "entry-view";
      }
      entry.text = "";
    });

    var pbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign = Align.CENTER,
      valign = Align.CENTER
    };
    pbox.append( lbl );
    pbox.append( entry );

    box.append( pbox );

  }

  /* Creates the current journal sidebar */
  private Box add_current_sidebar() {

    _entries = new SidebarEntries( _journals );

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

    _editor = new SidebarEditor( _journals );

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
      _lock_stack.visible_child_name = "lock-view";
    } else {
      _lock_stack.visible_child_name = "setlock-view";
    }
  }

  /* Called when the user uses the Control-q keyboard shortcut */
  private void action_quit() {
    destroy();
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

