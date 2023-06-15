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
  private Entry          _title;
  private Label          _date;
  private GtkSource.View _text;
  private Stack          _sidebar_stack;
  private Journals       _journals;
  private SidebarEntries _entries;
  private Journal        _edit_journal;
  private Entry          _edit_name;
  private TextView       _edit_description;
  private Revealer       _edit_del_revealer;
  private Button         _edit_save;

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
      resize_start_child = true,
      resize_end_child   = false,
      shrink_start_child = true,
      shrink_end_child   = false
    };
    child = pw;

    add_text_area( lbox );
    add_sidebar( rbox );

    show();

    /* Loads the application-wide CSS */
    load_css();

  }

  /* Creates the textbox with today's entry. */
  private void add_text_area( Box box ) {

    var text_margin  = 20;
    var line_spacing = 5;
    var font_size    = 14;

    /* Add the title */
    _title = new Entry() {
      placeholder_text = _( "Title (Optional)" ),
      has_frame        = false,
    };
    _title.add_css_class( "title" );
    _title.add_css_class( "text-background" );
    _title.add_css_class( "text-padding" );

    /* Add the date */
    _date = new Label( "" ) {
      halign = Align.FILL,
      xalign = (float)0
    };
    _date.add_css_class( "date" );
    _date.add_css_class( "text-background" );

    var sep = new Separator( Orientation.HORIZONTAL );

    /* Now let's setup some stuff related to the text field */
    var lang_mgr = GtkSource.LanguageManager.get_default();
    var lang     = lang_mgr.get_language( "markdown" );

    var style_mgr = GtkSource.StyleSchemeManager.get_default();
    var style     = style_mgr.get_scheme( "cobalt-light" );
    foreach( string id in style_mgr.get_scheme_ids() ) {
      stdout.printf( "  scheme: %s\n", id );
    }

    /* Create the text entry view */
    var buffer = new GtkSource.Buffer.with_language( lang ) {
      style_scheme = style
    };
    _text = new GtkSource.View.with_buffer( buffer ) {
      valign             = Align.FILL,
      vexpand            = true,
      top_margin         = text_margin / 2,
      left_margin        = text_margin,
      bottom_margin      = text_margin,
      right_margin       = text_margin,
      wrap_mode          = WrapMode.WORD,
      pixels_below_lines = line_spacing,
      pixels_inside_wrap = line_spacing
    };
    _text.add_css_class( "journal-text" );

    var provider = new CssProvider();
    var css_data = """
      .journal-text {
        font-size: %dpt;
      }
      .title {
        font-size: %dpt;
        border: none;
        box-shadow: none;
      }
      .date {
        padding-left: %dpx;
        padding-bottom: 5px;
      }
      .text-background {
        background-color: %s;
      }
      .text-padding {
        padding-left: %dpx;
        padding-right: %dpx;
        padding-top: %dpx;
        padding-bottom: %dpx;
      }
    """.printf( font_size, font_size, text_margin, style.get_style( "background-pattern" ).background, (text_margin - 4), (text_margin - 4), 0, 0 );
    provider.load_from_data( css_data.data );
    StyleContext.add_provider_for_display( get_display(), provider, STYLE_PROVIDER_PRIORITY_APPLICATION );

    var scroll = new ScrolledWindow() {
      vscrollbar_policy = PolicyType.AUTOMATIC,
      child = _text
    };

    box.append( _title );
    box.append( _date );
    box.append( sep );
    box.append( scroll );

  }

  /* Adds the sidebar */
  private void add_sidebar( Box box ) {

    _sidebar_stack = new Stack();
    _sidebar_stack.add_named( add_current_sidebar(), "entries" );
    _sidebar_stack.add_named( add_journal_edit(),    "journal" );

    box.append( _sidebar_stack );

  }

  /* Sets up the journal editor panel and then switches to it */
  private void edit_journal( Journal? journal ) {

    _edit_journal = journal;

    if( journal == null ) {
      _edit_name.text = "";
      _edit_description.buffer.text = "";
      _edit_save.sensitive = false;
      _edit_del_revealer.reveal_child = false;
    } else {
      _edit_name.text = journal.name;
      _edit_description.buffer.text = journal.description;
      _edit_save.sensitive = true;
      _edit_del_revealer.reveal_child = true;
    }

    _sidebar_stack.visible_child_name = "journal";

  }

  /* Creates the current journal sidebar */
  private Box add_current_sidebar() {

    _entries = new SidebarEntries();

    _entries.edit_journal.connect((journal) => {
      edit_journal( journal );
    });

    _entries.show_journal_entry.connect((journal, date) => {
      show_journal_entry( journal, date );
    });

    return( _entries );

  }

  /* Adds the journal editor to the sidebar */
  private Box add_journal_edit() {

    /* Edit name */
    var nlbl   = new Label( _( "Name:" ) );
    _edit_name = new Entry() {
      halign = Align.FILL
    };
    _edit_name.changed.connect(() => {
      var text = _edit_name.buffer.text;
      _edit_save.sensitive = ((text != "") && (_journals.get_journal_by_name( text ) == null));
    });
    var nbox = new Box( Orientation.HORIZONTAL, 5 );
    nbox.append( nlbl );
    nbox.append( _edit_name );

    /* Edit description */
    var dlbl = new Label( _( "Description:" ) ) {
      halign = Align.FILL,
      xalign = (float)0
    };
    _edit_description = new TextView() {
      halign    = Align.FILL,
      hexpand   = true,
      valign    = Align.FILL,
      vexpand   = true,
      wrap_mode = WrapMode.WORD
    };
    var dbox = new Box( Orientation.VERTICAL, 5 );
    dbox.append( dlbl );
    dbox.append( _edit_description );

    var del = new Button.with_label( _( "Delete" ) ) {
      // halign = Align.START
    };
    del.clicked.connect(() => {
      _journals.remove_journal( _edit_journal );
      _edit_journal = null;
      _sidebar_stack.visible_child_name = "entries";
    });
    del.add_css_class( "destructive-action" );
    _edit_del_revealer = new Revealer() {
      transition_duration = 0,
      child = del
    };
    var cancel = new Button.with_label( _( "Cancel" ) ) {
      // halign = Align.END
    };
    cancel.clicked.connect(() => {
      _sidebar_stack.visible_child_name = "entries";
    });
    _edit_save = new Button.with_label( _( "Save" ) ) {
      // halign = Align.END
    };
    _edit_save.add_css_class( "suggested-action" );
    _edit_save.clicked.connect(() => {
      if( _edit_journal == null ) {
        var journal = new Journal( _edit_name.buffer.text, _edit_description.buffer.text );
        _journals.add_journal( journal );
        _entries.populate_journal_list();
      } else {
        _edit_journal.name = _edit_name.buffer.text;
        _edit_journal.description = _edit_description.buffer.text;
        _journals.save();
      }
      _sidebar_stack.visible_child_name = "entries";
    });
    var rbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign = Align.END,
      hexpand = true,
    };
    rbox.append( cancel );
    rbox.append( _edit_save );

    var bbox = new Box( Orientation.HORIZONTAL, 5 ) {
      margin_top = 5,
      margin_bottom = 5,
      margin_start = 5,
      margin_end = 5
    };
    bbox.append( _edit_del_revealer );
    bbox.append( rbox );

    var box = new Box( Orientation.VERTICAL, 5 );
    box.append( nbox );
    box.append( dbox );
    box.append( bbox );

    return( box );

  }

  /* Displays the entry for the selected date */
  private void show_journal_entry( Journal journal, string date ) {

    var entry = new DBEntry();
    entry.date = date;

    var load_result = journal.db.load_entry( ref entry, false );
    set_buffer( entry, (load_result != DBLoadResult.FAILED) );

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

    var entry = new DBEntry.for_save( _title.text, _text.buffer.text );

    if( _journals.current.db.save_entry( entry ) ) {
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

  /* Sets the entry contents to the given entry, saving the previous contents, if necessary */
  private void set_buffer( DBEntry entry, bool editable ) {

    if( _text.buffer.get_modified() ) {
      action_save();
    }

    /* Set the title */
    _title.text = entry.title;
    _title.editable = editable;

    /* Set the date */
    var dt = entry.datetime();
    _date.label = dt.format( "%A, %B %e, %Y" );

    /* Set the buffer text to the entry text */
    _text.buffer.begin_irreversible_action();
    _text.buffer.text = entry.text;
    _text.buffer.end_irreversible_action();

    /* Set the editable bit */
    _text.editable = editable;

    /* Clear the modified bit */
    _text.buffer.set_modified( false );

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

