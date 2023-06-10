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

  private GLib.Settings    _settings;
  private GtkSource.Buffer _buffer;
  private ListBox          _listbox;
  // private Gtk.AccelGroup? _accel_group = null;
  // private UnicodeInsert   _unicoder;

  private const GLib.ActionEntry[] action_entries = {
    { "action_new_entry", action_new_entry },
    { "action_save",      action_save },
    { "action_quit",      action_quit },
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
    // destroy.connect( Gtk.main_quit );

    /* Set the stage for menu actions */
    var actions = new SimpleActionGroup ();
    actions.add_action_entries( action_entries, this );
    insert_action_group( "win", actions );

    /* Add keyboard shortcuts */
    add_keyboard_shortcuts( app );

    /* Create title toolbar */
    var new_btn = new Button.from_icon_name( get_header_icon_name( "document-new" ) );
    new_btn.set_tooltip_markup( Utils.tooltip_with_accel( _( "New Entry" ), "<Control>n" ) );
    new_btn.clicked.connect( action_new_entry );
    header.pack_start( new_btn );

    var lbox = new Box( Orientation.VERTICAL, 0 );
    var rbox = new Box( Orientation.VERTICAL, 0 );

    var pw = new Paned( Orientation.HORIZONTAL ) {
      start_child        = lbox,
      end_child          = rbox,
      shrink_start_child = true,
      shrink_end_child   = false
    };
    child = pw;

    add_text_area( lbox );
    add_sidebar( rbox );

    show();

    /* Loads the application-wide CSS */
    load_css();

    Timeout.add(1000, () => {
      pw.position = get_allocated_width() - 200;
      pw.position_set = true;
      populate_listbox();
      load_today_entry();
      return( false );
    });

  }

  /* Creates the textbox with today's entry. */
  private void add_text_area( Box box ) {

    var text_margin  = 20;
    var line_spacing = 5;
    var font_size    = 14;

    /* Now let's setup some stuff related to the text field */
    var lang_mgr = GtkSource.LanguageManager.get_default();
    var lang     = lang_mgr.get_language( "markdown" );

    var style_mgr = GtkSource.StyleSchemeManager.get_default();
    var style     = style_mgr.get_scheme( "cobalt" );
    foreach( string id in style_mgr.get_scheme_ids() ) {
      stdout.printf( "  scheme: %s\n", id );
    }

    /* Create the text entry view */
    _buffer = new GtkSource.Buffer.with_language( lang ) {
      style_scheme = style
    };
    var entry = new GtkSource.View.with_buffer( _buffer ) {
      valign        = Align.FILL,
      vexpand       = true,
      top_margin    = text_margin,
      left_margin   = text_margin,
      bottom_margin = text_margin,
      right_margin  = text_margin,
      wrap_mode     = WrapMode.WORD,
      pixels_below_lines = line_spacing,
      pixels_inside_wrap = line_spacing

    };

    var provider = new CssProvider();
    provider.load_from_data( "textview { font-size: %dpt; }".printf( font_size ).data );
    entry.get_style_context().add_provider( provider, STYLE_PROVIDER_PRIORITY_APPLICATION );

    var scroll = new ScrolledWindow() {
      vscrollbar_policy = PolicyType.AUTOMATIC,
      child = entry
    };

    box.append( scroll );

  }

  /* Adds the sidebar */
  private void add_sidebar( Box box ) {

    _listbox = new ListBox() {
      valign  = Align.FILL,
      vexpand = true,
      halign  = Align.FILL,
      hexpand = true
    };
    _listbox.row_selected.connect((row) => {
      stdout.printf( "HERE!\n" );
    });

    var lb_scroll = new ScrolledWindow() {
      vscrollbar_policy = PolicyType.AUTOMATIC,
      child = _listbox
    };

    box.append( lb_scroll );

  }

  /* Loads the application-wide CSS */
  private void load_css() {
    var provider = new CssProvider();
    provider.load_from_resource( "/com/github/phase1geo/journaler/Application.css" );
    get_style_context().add_provider( provider, STYLE_PROVIDER_PRIORITY_APPLICATION );
  }

  /* Populates the all entries listbox with date from the database */
  private void populate_listbox() {

    var entries = new Array<DBEntry>();

    if( !Journaler.db.get_all_entries( ref entries ) ) {
      stdout.printf( "ERROR:  Unable to get all entries in the journal\n" );
      return;
    }

    for( int i=0; i<entries.length; i++ ) {
      var label = new Label( entries.index( i ).gen_title() ) {
        halign  = Align.START,
        hexpand = true
      };
      label.add_css_class( "listbox-head" );
      var date = new Label( entries.index( i ).date ) {
        halign  = Align.END,
        hexpand = true
      };
      var box = new Box( Orientation.VERTICAL, 0 ) {
        halign        = Align.START,
        margin_top    = 5,
        margin_bottom = 5,
        margin_start  = 5,
        margin_end    = 5
      };
      box.append( label );
      box.append( date );
      _listbox.append( box );
    }

  }

  /* Returns the name of the icon to use for a headerbar icon */
  private string get_header_icon_name( string icon_name ) {
    return( "%s%s".printf( icon_name, (on_elementary ? "" : "-symbolic") ) );
  }

  /* Adds keyboard shortcuts for the menu actions */
  private void add_keyboard_shortcuts( Gtk.Application app ) {

    app.set_accels_for_action( "win.action_new_entry", { "<Control>n" } );
    app.set_accels_for_action( "win.action_save",      { "<Control>s" } );
    app.set_accels_for_action( "win.action_quit",      { "<Control>q" } );

  }

  /* Creates a new file */
  public void action_new_entry() {

    // TBD

  }

  /* Save the current entry to the database */
  public void action_save() {

    var entry = new DBEntry.for_save( "", _buffer.text );

    if( Journaler.db.save_entry( entry ) ) {
      stdout.printf( "Saved successfully!\n" );
    } else {
      stdout.printf( "Save did not occur\n" );
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

  /* Loads the entry in the database for today */
  private void load_today_entry() {

    DBEntry entry = new DBEntry();

    if( Journaler.db.load_entry( ref entry ) ) {
      stdout.printf( "Successfully loaded!\n" );
      _buffer.text = entry.text;
    } else {
      stdout.printf( "Uh-oh. No load\n" );
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

