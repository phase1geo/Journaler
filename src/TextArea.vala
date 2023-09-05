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
using WebKit;

public class TextArea : Box {

  private MainWindow       _win;
  private Journals         _journals;
  private Templates        _templates;
  private Journal?         _journal = null;
  private DBEntry?         _entry = null;
  private ImageArea        _image_area;
  private Entry            _title;
  private MenuButton       _burger;
  private Label            _date;
  private TagBox           _tags;
  private GtkSource.View   _text;
  private GtkSource.Buffer _buffer;
  private WebView          _viewer;
  private bool             _allow_viewer_update = false;
  private Stack            _text_stack;
  private string           _theme;
  private GLib.Menu        _image_menu;
  private GLib.Menu        _templates_menu;
  private Statistics       _stats;
  private Label            _quote;
  private Revealer         _quote_revealer;
  private Quotes           _quotes;
  private SpellChecker     _spell;
  private bool             _entry_goal_reached = false;

  private const GLib.ActionEntry action_entries[] = {
    { "action_add_entry_image",     action_add_entry_image },
    { "action_remove_entry_image",  action_remove_entry_image },
    { "action_insert_template",     action_insert_template, "s" },
    { "action_restore_entry",       action_restore_entry },
    { "action_delete_entry",        action_delete_entry },
    { "action_trash_entry",         action_trash_entry },
    { "action_bold_text",           action_bold_text },
    { "action_italicize_text",      action_italicize_text },
    { "action_code_text",           action_code_text },
    { "action_header_text",         action_header_text, "i" },
    { "action_h1_text",             action_h1_text },
    { "action_ordered_list_text",   action_ordered_list_text },
    { "action_unordered_list_text", action_unordered_list_text },
    { "action_task_text",           action_task_text },
    { "action_task_done_text",      action_task_done_text },
    { "action_remove_markup",       action_remove_markup },
  };

  public ImageArea image_area {
    get {
      return( _image_area );
    }
  }

  public signal void entry_moved( DBEntry entry );

  /* Create the main window UI */
  public TextArea( Gtk.Application app, MainWindow win, Journals journals, Templates templates ) {

    Object( orientation: Orientation.VERTICAL, spacing: 0 );

    _win       = win;
    _journals  = journals;
    _templates = templates;

    /* Create the list of quotes to use */
    _quotes = new Quotes();

    /* Update the templates menu */
    _templates.changed.connect((name, added) => {
      _templates_menu.remove_all();
      foreach( var template in _templates.templates ) {
        _templates_menu.append( template.name, "textarea.action_insert_template('%s')".printf( template.name ) );
      }
    });

    /* Add the UI components */
    add_text_area();

    /* Set the CSS for this widget */
    win.themes.theme_changed.connect((name) => {
      _theme = name;
      update_theme();
    });
    Journaler.settings.changed.connect((key) => {
      switch( key ) {
        case "editor-font-size"    :  set_font_size();      break;
        case "editor-margin"       :  set_margin( false );  break;
        case "editor-line-spacing" :  set_line_spacing();   break;
        case "enable-spellchecker" :  set_spellchecker();   break;
        case "enable-quotations"   :  
          if( _buffer.text == "" ) {
            _quote_revealer.reveal_child = Journaler.settings.get_boolean( "enable-quotations" );
          }
          break;
      }
    });

    /* Add the menu actions */
    var actions = new SimpleActionGroup();
    actions.add_action_entries( action_entries, this );
    insert_action_group( "textarea", actions );

    /* Add keyboard shortcuts */
    add_keyboard_shortcuts( app );

  }

  /* Add keyboard shortcuts */
  private void add_keyboard_shortcuts( Gtk.Application app ) {

    app.set_accels_for_action( "textarea.action_bold_text",           { "<Control>b" } );
    app.set_accels_for_action( "textarea.action_italicize_text",      { "<Control>i" } );
    app.set_accels_for_action( "textarea.action_code_text",           { "<Control>m" } );
    app.set_accels_for_action( "textarea.action_h1_text",             { "<Control>h" } );
    app.set_accels_for_action( "textarea.action_ordered_list_text",   { "<Control>numbersign" } );
    app.set_accels_for_action( "textarea.action_unordered_list_text", { "<Control>minus" } );
    app.set_accels_for_action( "textarea.action_task_text",           { "<Control>bracketleft" } );
    app.set_accels_for_action( "textarea.action_task_done_text",      { "<Control>bracketright" } );
    app.set_accels_for_action( "textarea.action_remove_markup",       { "<Control><Shift>r" } );

  }

  /* Sets the font size of the text widget */
  private void set_font_size() {

    update_theme();
    
  }

  /* Sets the margin around the text widget */
  private void set_margin( bool init ) {

    var margin = Journaler.settings.get_int( "editor-margin" );

    _text.top_margin    = margin / 2;
    _text.left_margin   = margin;
    _text.right_margin  = margin;

    Timeout.add(100, () => {
      var height = _text.get_allocated_height();
      if( height > 0 ) {
        _text.bottom_margin = height / 2;
        return( false );
      }
      return( true );
    });

    if( !init ) {
      update_theme();
    }

  }

  /* Sets the text line spacing */
  private void set_line_spacing() {

    var line_spacing = Journaler.settings.get_int( "editor-line-spacing" );

    _text.pixels_below_lines = line_spacing;
    _text.pixels_inside_wrap = line_spacing;

  }

  /* Enables or disables the spellchecker */
  private void set_spellchecker() {

    if( Journaler.settings.get_boolean( "enable-spellchecker" ) ) {
      _spell.attach( _text );
    } else {
      _spell.detach();
    }

  }

  /* Returns the widget that should receive the grab focus when this pane is placed into view */
  public Widget get_focus_widget() {

    return( _title );

  }

  /* Creates the textbox with today's entry. */
  private void add_text_area() {

    /* Add the title */
    var title_focus = new EventControllerFocus();
    _title = new Entry() {
      halign                  = Align.FILL,
      hexpand                 = true,
      placeholder_text        = _( "Title (Optional)" ),
      has_frame               = false,
      enable_emoji_completion = true
    };
    _title.add_controller( title_focus );
    _title.add_css_class( "title" );
    _title.add_css_class( "text-background" );
    _title.add_css_class( "text-padding" );

    /* Create the menubutton itself */
    _burger = new MenuButton() {
      icon_name  = "view-more-symbolic",
      halign     = Align.END,
      menu_model = create_burger_menu( false )
    };

    var tbox = new Box( Orientation.HORIZONTAL, 5 );
    tbox.add_css_class( "title-box" );
    tbox.add_css_class( "text-background" );
    tbox.append( _title );
    tbox.append( _burger );

    /* Add the date */
    _date = new Label( "" ) {
      halign = Align.FILL,
      xalign = (float)0
    };
    _date.add_css_class( "date" );
    _date.add_css_class( "text-background" );

    /* Add the tags */
    _tags = new TagBox( _win );

    /* Delay adding the CSS classes to clean up a Gtk4 issue */
    Idle.add(() => {
      _tags.add_class( "date" );
      _tags.add_class( "text-background" );
      return( false );
    });

    var sep1 = new Separator( Orientation.HORIZONTAL );
    var sep2 = new Separator( Orientation.HORIZONTAL );

    /* Add the quote region */
    _quote = new Label( "" ) {
      halign    = Align.FILL,
      hexpand   = true,
      xalign    = (float)0,
      wrap      = true
    };
    _quote.add_css_class( "text-background" );
    _quote.add_css_class( "quote" );
    _quote_revealer = new Revealer() {
      reveal_child = false,
      child        = _quote
    };

    _text_stack = new Stack();
    _text_stack.add_named( create_text_editor(), "editor" );
    _text_stack.add_named( create_text_viewer(), "viewer" );

    _title.activate.connect(() => {
      _text.grab_focus();
    });
    _title.changed.connect(() => {
      _win.reset_timer();
      if( _title.text == "" ) {
        _title.remove_css_class( "title-bold" );
      } else {
        _title.add_css_class( "title-bold" );
      }
    });

    title_focus.leave.connect(() => {
      _title.select_region( 0, 0 );
      save();
    });

    /* Create statistics bar */
    _stats = new Statistics( _text.buffer );

    append( tbox );
    append( _date );
    append( _tags );
    append( sep1 );
    append( _quote_revealer );
    append( _text_stack );
    append( sep2 );
    append( _stats );

    initialize_spell_checker();

  }

  /* Creates the text viewer when editing an entry */
  private Widget create_text_editor() {

    /* Create image area */
    _image_area = new ImageArea( _win );

    /* Now let's setup some stuff related to the text field */
    var lang_mgr = GtkSource.LanguageManager.get_default();
    var lang     = lang_mgr.get_language( "markdown" );

    /* Create the list of shortcuts */
    var bold_shortcut      = new Shortcut( ShortcutTrigger.parse_string( "<Control>b" ),            ShortcutAction.parse_string( "action(textarea.action_bold_text)" ) );
    var italic_shortcut    = new Shortcut( ShortcutTrigger.parse_string( "<Control>i" ),            ShortcutAction.parse_string( "action(textarea.action_italicize_text)" ) ); 
    var code_shortcut      = new Shortcut( ShortcutTrigger.parse_string( "<Control>m" ),            ShortcutAction.parse_string( "action(textarea.action_code_text)" ) );
    var header_shortcut    = new Shortcut( ShortcutTrigger.parse_string( "<Control>h" ),            ShortcutAction.parse_string( "action(textarea.action_h1_text)" ) );
    var ordered_shortcut   = new Shortcut( ShortcutTrigger.parse_string( "<Control>numbersign" ),   ShortcutAction.parse_string( "action(textarea.action_ordered_list_text)" ) );
    var unordered_shortcut = new Shortcut( ShortcutTrigger.parse_string( "<Control>minus" ),        ShortcutAction.parse_string( "action(textarea.action_unordered_list_text)" ) );
    var task_shortcut      = new Shortcut( ShortcutTrigger.parse_string( "<Control>bracketleft" ),  ShortcutAction.parse_string( "action(textarea.action_task_text)" ) );
    var done_shortcut      = new Shortcut( ShortcutTrigger.parse_string( "<Control>bracketright" ), ShortcutAction.parse_string( "action(textarea.action_task_done_text)" ) );
    var remove_shortcut    = new Shortcut( ShortcutTrigger.parse_string( "<Shift><Control>r" ),     ShortcutAction.parse_string( "action(textarea.action_remove_markup)" ) );

    /* Create the text entry view */
    _buffer = new GtkSource.Buffer.with_language( lang );
    _text = new GtkSource.View.with_buffer( _buffer ) {
      valign          = Align.FILL,
      vexpand         = true,
      wrap_mode       = WrapMode.WORD,
      cursor_visible  = true,
      enable_snippets = true
    };

    populate_extra_menu();

    _text.add_controller( _image_area.create_image_drop() );
    _text.add_css_class( "journal-text" );

    _text.add_shortcut( bold_shortcut );
    _text.add_shortcut( italic_shortcut );
    _text.add_shortcut( code_shortcut );
    _text.add_shortcut( header_shortcut );
    _text.add_shortcut( ordered_shortcut );
    _text.add_shortcut( unordered_shortcut );
    _text.add_shortcut( task_shortcut );
    _text.add_shortcut( done_shortcut );
    _text.add_shortcut( remove_shortcut );

    _buffer.apply_tag.connect((tag, start, end) => {
      var text = _buffer.get_text( start, end, false );
      _image_area.add_image_from_uri( text );
    });
    _buffer.changed.connect(() => {
      _win.reset_timer();
      if( _quote_revealer.reveal_child && Journaler.settings.get_boolean( "dismiss-quotation-on-write" ) ) {
        _quote_revealer.transition_duration = 2000;
        _quote_revealer.reveal_child        = false;
      }
    });

    set_line_spacing();
    set_margin( true );

    var tscroll = new ScrolledWindow() {
      vscrollbar_policy = PolicyType.AUTOMATIC,
      child = _text
    };
    tscroll.scroll_child.connect((t,h) => {
      _win.reset_timer();
      return( false );
    });

    var box = new Box( Orientation.VERTICAL, 0 );
    box.append( tscroll );
    box.append( _image_area );

    return( box );

  }

  /* Creates the text viewer when displaying read-only entries */
  private Widget create_text_viewer() {

    var ta = this;

    var wk_settings = new WebKit.Settings();
    wk_settings.set_allow_file_access_from_file_urls( true );
    wk_settings.set_allow_top_navigation_to_data_urls( true );

    _viewer = new WebView() {
      settings = wk_settings
    };

    _viewer.decide_policy.connect((decision, type) => {
      if( ta._allow_viewer_update ) {
        ta._allow_viewer_update = false;
      } else {
        if( type == PolicyDecisionType.NAVIGATION_ACTION ) {
          var nav     = (NavigationPolicyDecision)decision;
          var action  = nav.get_navigation_action();
          var request = action.get_request();
          var uri     = request.uri;
          Utils.open_url( uri );
        }
        decision.ignore();
      }
      return( false );
    });

    return( _viewer );

  }

  /* Connects the text widget to the spell checker */
  private void initialize_spell_checker() {

    _spell = new SpellChecker();
    _spell.populate_extra_menu.connect( populate_extra_menu );

    var lang_exists = false;
    var lang      = Environment.get_variable( "LANGUAGE" );
    var lang_list = new Gee.ArrayList<string>();
    _spell.get_language_list( lang_list );

    lang_list.foreach((elem) => {
      if( elem == lang ) {
        _spell.set_language( lang );
        lang_exists = true;
        return( false );
      }
      return( true );
    });

    if( lang_list.size == 0 ) {
      _spell.set_language( null );
    } else if( !lang_exists ) {
      _spell.set_language( lang_list.get( 0 ) );
    }

    set_spellchecker();

  }

  /* Adds the extra menu for the textview */
  private void populate_extra_menu() {

    /* Create extra menu */
    var formatter_menu = new GLib.Menu();
    formatter_menu.append( "Bold",      "textarea.action_bold_text" );
    formatter_menu.append( "Italicize", "textarea.action_italicize_text" );
    formatter_menu.append( "Monospace", "textarea.action_code_text" );

    var header_menu = new GLib.Menu();
    header_menu.append( "Header 1", "textarea.action_h1_text" );
    header_menu.append( "Header 2", "textarea.action_header_text(2)" );
    header_menu.append( "Header 3", "textarea.action_header_text(3)" );
    header_menu.append( "Header 4", "textarea.action_header_text(4)" );
    header_menu.append( "Header 5", "textarea.action_header_text(5)" );
    header_menu.append( "Header 6", "textarea.action_header_text(6)" );

    var start_menu = new GLib.Menu();
    start_menu.append( "Unordered List", "textarea.action_ordered_list_text" );
    start_menu.append( "Ordered List",   "textarea.action_unordered_list_text" );
    start_menu.append( "Task",           "textarea.action_task_text" );
    start_menu.append( "Task Done",      "textarea.action_task_done_text" );

    var deformat_menu = new GLib.Menu();
    deformat_menu.append( "Remove Formatting", "textarea.action_remove_markup" );

    var format_menu = new GLib.Menu();
    format_menu.append_section( null, formatter_menu );
    format_menu.append_section( null, header_menu );
    format_menu.append_section( null, deformat_menu );

    var format_submenu = new GLib.Menu();
    format_submenu.append_submenu( _( "Format Text" ), format_menu );

    var extra = new GLib.Menu();
    extra.append_section( null, format_submenu );

    /* Finally, add the extra menu to the textview */
    _text.extra_menu = extra;

  }

  /* Creates burger menu and populates it with features */
  private MenuModel create_burger_menu( bool for_trash ) {

    GLib.Menu menu = new GLib.Menu();

    if( for_trash ) {

      menu.append( _( "Restore entry" ),            "textarea.action_restore_entry" );
      menu.append( _( "Delete entry permanently" ), "textarea.action_delete_entry" );

    } else {

      /* Create image menu */
      _image_menu = new GLib.Menu();
      _image_menu.append( _( "Add Image" ), "textarea.action_add_entry_image" );

      /* Create templates menu */
      _templates_menu = new GLib.Menu();

      var template_menu = new GLib.Menu();
      template_menu.append_submenu( _( "Insert Template" ), _templates_menu );

      /* Create trash menu */
      var trash_menu = new GLib.Menu();
      trash_menu.append( _( "Move entry to trash" ), "textarea.action_trash_entry" );

      menu.append_section( null, _image_menu );
      menu.append_section( null, template_menu );
      menu.append_section( null, trash_menu );

    }

    return( menu );

  }

  /* Adds or changes the image associated with the current entry */
  private void action_add_entry_image() {
    _win.reset_timer();
    _image_area.add_new_image();
  }

  /* Removes the image associated with the current entry */
  private void action_remove_entry_image() {
    _win.reset_timer();
  }

  /* Inserts the given template text at the current insertion cursor location */
  private void action_insert_template( SimpleAction action, Variant? variant ) {
    _win.reset_timer();
    insert_template( variant.get_string() );
  }

  /* Moves the current entry to the trash */
  private void action_trash_entry() {

    var journal = _journals.get_journal_by_name( _entry.journal );
    if( journal != null ) {

      /* Save the current entry so that we have _entry up-to-date */
      save();

      var load_entry     = new DBEntry();
      load_entry.journal = _entry.journal;
      load_entry.date    = _entry.date;

      var load_result = _journals.trash.db.load_entry( load_entry, true );

      if( load_result != DBLoadResult.FAILED ) {
        load_entry.merge_with_entry( _entry );
        if( journal.move_entry( load_entry, _journals.trash ) ) {
          entry_moved( _entry );
          stdout.printf( "Entry successfully moved to the trash\n" );
        }
      }

    }

  }

  /* Moves an entry from the trash back to the originating journal */
  private void action_restore_entry() {

    var journal = _journals.get_journal_by_name( _entry.journal );

    /* If the journal needs to be created, do it now */
    if( journal == null ) {
      string template    = "";
      string description = "";
      if( _journals.trash.db.load_journal( _entry.journal, out template, out description ) ) {
        journal = new Journal( _entry.journal, template, description );
        _journals.add_journal( journal, true );
      } else {
        return;
      }
    }

    /* Save the current entry to the original journal and then remove it from the trash */
    if( _journals.trash.move_entry( _entry, journal ) ) {
      entry_moved( _entry );
      stdout.printf( "Entry successfully restored from trash\n" );
    }

  }

  /* Permanently delete the entry from the trash */
  private void action_delete_entry() {

    if( _journals.trash.db.remove_entry( _entry ) ) {
      entry_moved( _entry );
      stdout.printf( "Entry permanently deleted from trash\n" );
    }

  }

  /*
   If text is currently selected, make sure the selection is adjusted such that the start of
   the selection is not on a whitespace character and the end selection is one character to the
   right of a non-whitespace character.
  */
  private bool get_markup_selection( out TextIter start, out TextIter end ) {
    if( _buffer.get_selection_bounds( out start, out end ) ) {
      if( start.get_char().isspace() ) {
        start.forward_find_char( (c) => { return( !c.isspace() ); }, null );
      }
      end.backward_char();
      if( end.get_char().isspace()  ) {
        end.backward_find_char( (c) => { return( !c.isspace() ); }, null );
      }
      end.forward_char();
      return( start.compare( end ) <= 0 );
    }
    return( false );
  }

  /* Adds the given text markup based on whether valid text is selected or not */
  private void add_text_markup( string prefix, string suffix = "" ) {

    TextIter sel_start, sel_end;

    if( get_markup_selection( out sel_start, out sel_end ) ) {

      _buffer.begin_user_action();

      if( suffix == "" ) {
        sel_start.set_line( sel_start.get_line() );
        _buffer.insert( ref sel_start, prefix, prefix.length );
      } else {
        _buffer.insert( ref sel_start, prefix, prefix.length );
        get_markup_selection( out sel_start, out sel_end );
        _buffer.insert( ref sel_end, suffix, suffix.length );
      }

      _buffer.select_range( sel_end, sel_end );
      _buffer.end_user_action();

    } else {

      TextIter cursor;

      _buffer.begin_user_action();

      if( suffix == "" ) {
        _buffer.get_iter_at_mark( out cursor, _buffer.get_insert() );
        cursor.set_line( cursor.get_line() );
        _buffer.insert( ref cursor, prefix, prefix.length );
      } else {
        var text = prefix + suffix;
        _buffer.insert_at_cursor( text, text.length );
        _buffer.get_iter_at_mark( out cursor, _buffer.get_insert() );
      }

      cursor.backward_chars( suffix.char_count() );
      _buffer.place_cursor( cursor );
      _buffer.end_user_action();

    }

    _text.grab_focus();

  }

  private void get_markup_range( bool line, out TextIter start, out TextIter end ) {

    /* Get the string to replace */
    if( _buffer.get_selection_bounds( out start, out end ) ) {
      if( line ) {
        start.set_line( start.get_line() );
        end.forward_to_line_end();
      }
    } else {
      _buffer.get_iter_at_mark( out start, _buffer.get_insert() );
      end = start;
      start.set_line( start.get_line() );
      end.forward_to_line_end();
    }

  }

  /* Returns true if the selected text contains the given markup pattern */
  private bool contains_markup( string pattern ) {

    TextIter start, end;

    get_markup_range( (pattern.get_char( 0 ) == '^'), out start, out end );

    var text = _buffer.get_text( start, end, false );

    try {
      var re = new Regex( pattern, RegexCompileFlags.MULTILINE );
      return( re.match( text ) );
    } catch( RegexError e ) {
      stderr.printf( "ERROR: %s\n", e.message );
    }

    return( false );

  }

  /* Removes any markup that matches the given regex pattern */
  private void remove_markup( string pattern ) {

    TextIter start, end;

    get_markup_range( (pattern.get_char( 0 ) == '^'), out start, out end );

    var text = _buffer.get_text( start, end, false );

    try {
      var re = new Regex( pattern, RegexCompileFlags.MULTILINE );
      var new_text = re.replace_literal( text, text.length, 0, "" );
      if( new_text != text ) {
        _buffer.begin_user_action();
        _buffer.delete( ref start, ref end );
        _buffer.insert( ref start, new_text, new_text.length );
        end = start;
        end.backward_chars( new_text.char_count() );
        _buffer.select_range( start, end );
        _buffer.end_user_action();
      }
    } catch( RegexError e ) {
      stderr.printf( "ERROR: %s\n", e.message );
    }

  }

  /* Adds Markdown bold syntax around selected text */
  private void action_bold_text() {
    add_text_markup( "**", "**" );
  }

  /* Adds Markdown italic syntax around selected text */
  private void action_italicize_text() {
    add_text_markup( "_", "_" );
  }

  /* Adds Markdown code syntax around selected text */
  private void action_code_text() {

    TextIter start, end;

    if( _buffer.get_selection_bounds( out start, out end ) && start.starts_line() && end.ends_line() ) {
      add_text_markup( "```\n", "\n```" );
    } else if( contains_markup( "`" ) ) {
      add_text_markup( "``", "``" );
    } else {
      add_text_markup( "`", "`" );
    }

  }

  /* Adds Markdown header syntax around selected text */
  private void action_header_text( SimpleAction action, Variant? variant ) {

    var type   = variant.get_int32();
    var syntax = string.nfill( type, '#' ) + " ";

    _buffer.begin_user_action();
    remove_markup( "^#{1,6} " );
    add_text_markup( syntax );
    _buffer.end_user_action();

  }

  /* Adds an H1 header syntax at the beginning of the selected text */
  private void action_h1_text() {
    if( contains_markup( "^#{1,5} " ) ) {
      add_text_markup( "#" );
    } else {
      _buffer.begin_user_action();
      remove_markup( "^#{1,6} " );
      add_text_markup( "# " );
      _buffer.end_user_action();
    }
  }

  /* Inserts ordered list numbers at the beginning of each non-empty line */
  private void action_ordered_list_text() {

    _buffer.begin_user_action();

    remove_markup( "^([-*+]|[0-9]+\\.) " );

    TextIter start, end;
    get_markup_range( true, out start, out end );
    var endrange = _buffer.create_mark( "endrange", end, true );

    int index = 1;
    while( start.compare( end ) < 0 ) {
      TextIter cend = start;
      if( !cend.ends_line() ) {
        cend.forward_to_line_end();
      }
      if( _buffer.get_text( start, cend, false ).strip() != "" ) {
        var text = "%d. ".printf( index++ );
        _buffer.insert( ref start, text, text.length );
      }
      start.forward_line();
      _buffer.get_iter_at_mark( out end, endrange );
    }

    _buffer.select_range( end, end );
    _buffer.end_user_action();
    _text.grab_focus();

  }

  /* Inserts unordered list (-) characters at the beginning of each non-empty line */
  private void action_unordered_list_text() {

    _buffer.begin_user_action();

    remove_markup( "^([-*+]|[0-9]+\\.) " );

    TextIter start, end;
    get_markup_range( true, out start, out end );
    var endrange = _buffer.create_mark( "endrange", end, true );

    while( start.compare( end ) < 0 ) {
      TextIter cend = start;
      if( !cend.ends_line() ) {
        cend.forward_to_line_end();
      }
      if( _buffer.get_text( start, cend, false ).strip() != "" ) {
        var text = "- ";
        _buffer.insert( ref start, text, text.length );
      }
      start.forward_line();
      _buffer.get_iter_at_mark( out end, endrange );
    }

    _buffer.select_range( end, end );
    _buffer.end_user_action();
    _text.grab_focus();

  }

  private string iter_string( TextIter iter ) {
    return( "%d.%d".printf( iter.get_line(), iter.get_line_offset() ) );
  }

  /* Inserts incomplete task strings at the beginning of each non-empty line */
  private void action_task_text() {

    _buffer.begin_user_action();

    remove_markup( "\\[[ xX]\\] " );

    TextIter start, end;
    get_markup_range( true, out start, out end );
    var endrange = _buffer.create_mark( "endrange", end, true );

    while( start.compare( end ) < 0 ) {
      TextIter cend = start;
      if( !cend.ends_line() ) {
        cend.forward_to_line_end();
      }
      if( _buffer.get_text( start, cend, false ).strip() != "" ) {
        var text = "[ ] ";
        _buffer.insert( ref start, text, text.length );
      }
      start.forward_line();
      _buffer.get_iter_at_mark( out end, endrange );
    }

    _buffer.select_range( end, end );
    _buffer.end_user_action();
    _text.grab_focus();

  }

  /* Inserts incomplete task strings at the beginning of each non-empty line */
  private void action_task_done_text() {

    _buffer.begin_user_action();

    remove_markup( "\\[[ xX]\\] " );

    TextIter start, end;
    get_markup_range( true, out start, out end );
    var endrange = _buffer.create_mark( "endrange", end, true );

    while( start.compare( end ) < 0 ) {
      TextIter cend = start;
      if( !cend.ends_line() ) {
        cend.forward_to_line_end();
      }
      if( _buffer.get_text( start, cend, false ).strip() != "" ) {
        var text = "[x] ";
        _buffer.insert( ref start, text, text.length );
      }
      start.forward_line();
      _buffer.get_iter_at_mark( out end, endrange );
    }

    _buffer.select_range( end, end );
    _buffer.end_user_action();
    _text.grab_focus();

  }

  /* Removes all markup from the selected area */
  private void action_remove_markup() {

    /* Remove the markup */
    remove_markup( "(^#+\\s+|`+|\\*+|_{1,2}|^-\\s+|^[0-9]+\\.\\s+|\\[[ xX]\\]\\s+)" );

    /* Deselect text */
    TextIter cursor;
    _buffer.get_iter_at_mark( out cursor, _buffer.get_insert() );
    _buffer.select_range( cursor, cursor );

    _text.grab_focus();

  }

  /* Inserts the given snippet name */
  private bool insert_template( string name ) {
    var snippet = _templates.get_snippet( name );
    if( snippet != null ) {
      TextIter iter;
      _buffer.get_iter_at_offset( out iter, _buffer.cursor_position );
      _text.push_snippet( snippet, ref iter );
      _text.grab_focus();
      return( true );
    }
    return( false );
  }

  /* Sets the theme and CSS classes */
  private void update_theme() {

    /* Update the text buffer theme */
    var style_mgr = GtkSource.StyleSchemeManager.get_default();
    var style = style_mgr.get_scheme( _theme );
    _buffer.style_scheme = style;

    var font_size = Journaler.settings.get_int( "editor-font-size" );
    var margin    = Journaler.settings.get_int( "editor-margin" );

    /* Set the CSS */
    var provider = new CssProvider();
    var css_data = """
      .journal-text {
        font-size: %dpt;
        font-family: monospace;
      }
      .title {
        font-size: %dpt;
        border: none;
        box-shadow: none;
      }
      .title-box {
        padding-top: 5px;
        padding-right: 5px;
      }
      .title-bold {
        font-weight: bold;
      }
      .tags {
        border-radius: 1em;
        background-color: rgba(0, 0, 0, 0.1);
        padding: 5px;
      }
      .tags:focus {
        background-color: rgba(0, 0, 0, 0.2);
      }
      .date {
        padding-left: %dpx;
        padding-bottom: 5px;
      }
      .quote {
        padding-left: %dpx;
        padding-right: 5px;
        padding-top: 5px;
        padding-bottom: 5px;
      }
      .text-background {
        background-color: %s;
      }
      .text-padding {
        padding: 0px %dpx;
      }
      .image-padding {
        padding: 5px;
      }
      .image-button {
        opacity: 0.7;
      }
    """.printf( font_size, font_size, margin, margin, style.get_style( "text" ).background, (margin - 4) );
    provider.load_from_data( css_data.data );
    StyleContext.add_provider_for_display( get_display(), provider, STYLE_PROVIDER_PRIORITY_APPLICATION );

    /* Handle the background color of the viewer */
    RGBA c = {(float)1.0, (float)1.0, (float)1.0, (float)1.0};
    c.parse( style.get_style( "text" ).background );
    _viewer.set_background_color( c );

  }

  /* Returns true if the title of the entry has changed since it was loaded */
  private bool title_changed() {
    return( _title.editable && (_title.text != _entry.title) );
  }

  /* Returns true if the text of the entry has changed since it was loaded */
  private bool text_changed() {
    return( _text.editable && _text.buffer.get_modified() );
  }

  /* Saves the contents of the text area as an entry in the current database */
  public void save( bool image_changed = false ) {

    /* If the text area is not editable or has not changed, there's no need to save */
    if( (_journal == null) || (_entry == null) || (!title_changed() && !_image_area.changed() && !text_changed()) ) {
      return;
    }

    var entry = new DBEntry.with_date( 
      _entry.journal, _title.text, _text.buffer.text, _tags.entry.get_tag_list(), _entry.date, _entry.time
    );

    _image_area.get_images( entry );

    if( _journal.db.save_entry( _journal, entry ) ) {

      if( (_journals.current == _journal) && (_title.text != _entry.text) ) {
        _journals.current_changed( true );
      }

      _entry = entry;

      /* Update the goals */
      if( _stats.goal_reached() && !_entry_goal_reached ) {
        _win.goals.mark_achievement( entry.date );
        _entry_goal_reached = true;
      }

      stdout.printf( "Saved successfully to journal %s\n", _journal.name );

    }

  }

  /* Sets the entry contents to the given entry, saving the previous contents, if necessary */
  public void set_buffer( DBEntry entry, bool editable ) {

    /* Save the current buffer before loading a new one */
    save();

    /* Update the burger menu, if necessary */
    if( (_journal == null) || (_journal.is_trash != _journals.current.is_trash) ) {
      _burger.menu_model = create_burger_menu( _journals.current.is_trash );
    }

    _journal = _journals.current;
    _entry   = entry;

    var enable_ui = editable && !_journal.is_trash && _entry.loaded;

    /* Set the title */
    _title.text      = entry.title;
    _title.editable  = enable_ui;
    _title.can_focus = enable_ui;
    _title.focusable = enable_ui;

    /* Set the date */
    if( entry.date == "" ) {
      _date.label = "";
    } else {
      var dt = entry.datetime();
      _date.label = dt.format( "%A, %B %e, %Y  %I:%M %p" );
    }

    /* Set the image */
    _image_area.set_images( _journal, entry );
    _image_area.editable = enable_ui;

    /* Set the tags */
    _tags.journal = _journal;
    _tags.entry   = entry;
    _tags.update_tags();
    _tags.editable = enable_ui;

    /* Show the quote of the day if the text field is empty */
    if( (entry.text == "") && Journaler.settings.get_boolean( "enable-quotations" ) && enable_ui ) {
      _quote.label                        = _quotes.get_quote();
      _quote_revealer.transition_duration = 0;
      _quote_revealer.reveal_child        = true;
    } else {
      _quote_revealer.transition_duration = 0;
      _quote_revealer.reveal_child        = false;
    }

    /* Set the buffer text to the entry text or insert the snippet */
    if( enable_ui ) {

      _text.buffer.begin_irreversible_action();
      _text.buffer.text = "";
      if( (entry.text != "") || !insert_template( _journals.current.template ) ) {
        _text.buffer.text = entry.text;
      }
      _text.buffer.end_irreversible_action();

      /* Set the editable bit */
      _text.editable  = enable_ui;
      _text.can_focus = enable_ui;
      _text.focusable = enable_ui;

      /* Clear the modified bits */
      _text.buffer.set_modified( false );

      _text_stack.visible_child_name = "editor";

      /* Remember if we previously reached our goal with this entry */
      _entry_goal_reached = _stats.goal_reached();

    } else {

      show_review();
      _text_stack.visible_child_name = "viewer";

    }

    /* Set the grab */
    if( enable_ui ) {
      var title_empty = _title.text == "";
      var tags_empty  = _tags.entry.tags.length() == 0;
      var text_empty  = _text.buffer.text == "";
      if( title_empty && tags_empty && text_empty ) {
        _title.grab_focus();
      } else if( tags_empty && text_empty ) {
        _tags.grab_focus();
      } else {
        _text.grab_focus();
      }
    }

    /* Handle other UI state related to the editable indicator */
    if( editable && _entry.loaded ) {
      _burger.show();
    } else {
      _burger.hide();
    }

  }

  /* Conditions the given Markdown text to improve the display */
  private string condition_markdown( string text ) {
    var new_text = text;
    add_markdown_images( _journal, _entry, ref new_text );
    return( new_text );
  }

  /* Returns the image size to use for the given image */
  private string get_image_size( string path ) {

    var canvas_width = get_allocated_width() - 20;
    var img_width    = 400;
    var img_height   = 300;

    Pixbuf.get_file_info( path, out img_width, out img_height );

    if( img_width > canvas_width ) {
      var scale  = (double)canvas_width / img_width;
      img_width  = (int)(img_width * scale);
      img_height = (int)(img_height * scale);
      return( " =%dx%d".printf( img_width, img_height ) );
    }

    return( "" );

  }

  /* Returns the image description for the given image */
  private string get_description( DBImage image ) {

    if( image.description != "" ) {
      return( " \"%s\"".printf( image.description ) );
    }

    return( "" );

  }

  /*
   Parses the given text to find embedded images, centers those images inline and then
   adds the remaining images to the end of the document centered as well.
  */
  private void add_markdown_images( Journal journal, DBEntry entry, ref string text ) {

    var images = new Gee.HashMap<string,DBImage>();
    foreach( var image in entry.images ) {
      images.set( image.uri, image );
    }

    try {
      MatchInfo match_info;
      var re = new Regex( "!\\[.*?\\]\\s*\\((.+?)\\)" );
      var start_pos = 0;
      while( re.match_full( text, -1, start_pos, 0, out match_info ) ) {
        int start, end;
        match_info.fetch_pos( 1, out start, out end );
        var uri      = text.slice( start, end );
        var new_uri  = uri;
        var text_len = text.char_count();
        if( images.has_key( uri ) ) {
          var img = images.get( uri );
          new_uri = img.image_path( journal );
          text    = text.splice( start, end, new_uri + get_image_size( new_uri ) + get_description( img ) );
          images.unset( uri );
        }
        match_info.fetch_pos( 0, out start, out end );
        start_pos = text.index_of_nth_char( text.char_count( end ) + (text.char_count() - text_len) );
      }
    } catch( RegexError e ) {
      stderr.printf( "ERROR:  add_markdown_images: %s\n", e.message );
    }

    /* Append the remaining images that weren't embedded */
    if( images.size > 0 ) {
      text += "\n\n---\n\n";
      foreach( var image in entry.images ) {
        if( images.has_key( image.uri ) ) {
          var new_uri = image.image_path( journal );
          text += "![](%s)\n\n".printf( new_uri + get_image_size( new_uri ) + get_description( image ) );
        }
      }
    }

  }

  /* Adds CSS to the HTML */
  private void show_review() {

    var html  = "";
    var flags = 0x47607004;
    var md    = condition_markdown( _entry.text );
    var mkd   = new Markdown.Document.gfm_format( md.data, flags );
    mkd.compile( flags );
    mkd.get_document( out html );

    var style_mgr = GtkSource.StyleSchemeManager.get_default();
    var style = style_mgr.get_scheme( _theme );
    var color = style.get_style( "text" ).foreground;
    var rowbg = _win.themes.dark_mode ? "255, 255, 255, 0.05" : "0, 0, 0, 0.1";

    var distraction_free = _win.distraction_free_mode ? """
      body {
        width: 50%;
        margin-left: auto;
        margin-right: auto;
      }
    """ : "";

    var prefix = """
      <!DOCTYPE html>
      <html>
        <head>
          <style>
            body {
              color: %s;
            }
            %s
            table, th, td {
              border: 1px solid;
            }
            table {
              // display: block;
              margin-left: auto;
              margin-right: auto;
              border-collapse: collapse;
            }
            th {
              background: rgba(%s);
            }
            th, td {
              padding: 8px;
            }
            tr:nth-child(odd) {
              background: rgba(%s);
            }
            img {
              display: block;
              margin-left: auto;
              margin-right: auto;
            }
          </style>
        </head>
        <body>
    """.printf( color, distraction_free, rowbg, rowbg );

    var suffix = """
        </body>
      </html>
    """;

    _allow_viewer_update = true;
    _viewer.load_html( (prefix + html + suffix), "file:///" );

  }

  /* Sets the reviewer mode */
  public void set_reviewer_mode( bool review_mode ) {
    set_buffer( _entry, !review_mode );
  }

  /* Sets the distraction free mode to the given value and updates the UI. */
  public void set_distraction_free_mode( bool mode ) {

    if( mode ) {
      if( !_text.editable ) {
        _stats.hide();
      }
      _image_area.hide();
      if( _win.review_mode ) {
        show_review();
      }
      Timeout.add( 100, () => {
        if( _win.is_fullscreen() ) {
          var width  = _text.get_allocated_width();
          var height = _text.get_allocated_height();
          _text.left_margin   = width / 4;
          _text.right_margin  = width / 4;
          _text.top_margin    = 100;
          _text.bottom_margin = height / 2;
          return( false );
        }
        return( true );
      });
    } else {
      _stats.show();
      _image_area.show();
      if( _win.review_mode ) {
        show_review();
      }
      set_margin( false );
    }

  }

}

