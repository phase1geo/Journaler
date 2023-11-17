/*
* Copyright (c) 2023 (https://github.com/phase1geo/Journaler)
*
* This program is free software; you can redistribute it and/or
* modify it under the terms of the GNU General Public
* License as published by the Free Software Foundation; either
* version 3 of the License, or (at your option) any later version.
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
  private Button           _prev;
  private Button           _next;
  private MenuButton       _burger;
  private MenuButton       _date;
  private Popover          _date_popover;
  private bool             _date_changed;
  private Label            _time;
  private MenuButton       _jname;
  private Calendar         _cal;
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
    { "action_insert_template",     action_insert_template, "s" },
    { "action_restore_entry",       action_restore_entry },
    { "action_delete_entry",        action_delete_entry },
    { "action_trash_entry",         action_trash_entry },
    { "action_change_journal",      action_change_journal, "s" },
    { "action_bold_text",           action_bold_text },
    { "action_italicize_text",      action_italicize_text },
    { "action_strike_text",         action_strike_text },
    { "action_code_text",           action_code_text },
    { "action_h1_text",             action_h1_text },
    { "action_h2_text",             action_h2_text },
    { "action_h3_text",             action_h3_text },
    { "action_h4_text",             action_h4_text },
    { "action_h5_text",             action_h5_text },
    { "action_h6_text",             action_h6_text },
    { "action_h1_ul_text",          action_h1_ul_text },
    { "action_h2_ul_text",          action_h2_ul_text },
    { "action_hr",                  action_hr },
    { "action_blockquote",          action_blockquote },
    { "action_ordered_list_text",   action_ordered_list_text },
    { "action_unordered_list_text", action_unordered_list_text },
    { "action_task_text",           action_task_text },
    { "action_task_done_text",      action_task_done_text },
    { "action_link_text",           action_link_text },
    { "action_image_text",          action_image_text },
    { "action_remove_markup",       action_remove_markup },
  };

  public ImageArea image_area {
    get {
      return( _image_area );
    }
  }

  public signal void entry_moved( DBEntry entry );
  public signal void show_previous_entry();
  public signal void show_next_entry();

  /* Create the main window UI */
  public TextArea( Gtk.Application app, MainWindow win, Journals journals, Templates templates ) {

    Object( orientation: Orientation.VERTICAL, spacing: 0 );

    _win       = win;
    _templates = templates;
    _journals  = journals;
    _journals.list_changed.connect( journals_changed );

    /* Create the list of quotes to use */
    _quotes = new Quotes();

    /* Update the templates menu */
    _templates.changed.connect( update_template_menu );

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

  /* Updates the template menu */
  private void update_template_menu( string name, bool added ) {
    Idle.add(() => {
      _templates_menu.remove_all();
      foreach( var template in _templates.templates ) {
        _templates_menu.append( template.name, "textarea.action_insert_template('%s')".printf( template.name ) );
      }
      return( false );
    });
  }

  /* Add keyboard shortcuts */
  private void add_keyboard_shortcuts( Gtk.Application app ) {

    app.set_accels_for_action( "textarea.action_bold_text",           { "<Control>b" } );
    app.set_accels_for_action( "textarea.action_italicize_text",      { "<Control>i" } );
    app.set_accels_for_action( "textarea.action_strike_text",         { "<Control>asciitilde" } );
    app.set_accels_for_action( "textarea.action_code_text",           { "<Control>m" } );
    app.set_accels_for_action( "textarea.action_h1_text",             { "<Control>1" } );
    app.set_accels_for_action( "textarea.action_h2_text",             { "<Control>2" } );
    app.set_accels_for_action( "textarea.action_h3_text",             { "<Control>3" } );
    app.set_accels_for_action( "textarea.action_h4_text",             { "<Control>4" } );
    app.set_accels_for_action( "textarea.action_h5_text",             { "<Control>5" } );
    app.set_accels_for_action( "textarea.action_h6_text",             { "<Control>6" } );
    app.set_accels_for_action( "textarea.action_h1_ul_text",          { "<Control>equal" } );
    app.set_accels_for_action( "textarea.action_h2_ul_text",          { "<Control>minus" } );
    app.set_accels_for_action( "textarea.action_blockquote",          { "<Control>greater" } );
    app.set_accels_for_action( "textarea.action_hr",                  { "<Control>h" } );
    app.set_accels_for_action( "textarea.action_ordered_list_text",   { "<Control>numbersign" } );
    app.set_accels_for_action( "textarea.action_unordered_list_text", { "<Control>asterisk" } );
    app.set_accels_for_action( "textarea.action_task_text",           { "<Control>bracketleft" } );
    app.set_accels_for_action( "textarea.action_task_done_text",      { "<Control>bracketright" } );
    app.set_accels_for_action( "textarea.action_link_text",           { "<Control>k" } );
    app.set_accels_for_action( "textarea.action_image_text",          { "<Control><Shift>k" } );
    app.set_accels_for_action( "textarea.action_remove_markup",       { "<Control><Shift>r" } );

  }

  /* Sets the font size of the text widget */
  private void set_font_size() {

    update_theme();
    
  }

  /* Sets the margin around the text widget */
  private void set_margin( bool init ) {

    var margin = Journaler.settings.get_int( "editor-margin" );

    _title.margin_start = margin;
    _date.margin_start  = margin;
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

    _prev = new Button.from_icon_name( "go-previous-symbolic" ) {
      halign = Align.END,
      tooltip_markup = Utils.tooltip_with_accel( _( "View previous entry in sidebar" ), "<Control>Left" )
    };
    _prev.clicked.connect( action_show_previous_entry );
    _prev.hide();

    _next = new Button.from_icon_name( "go-next-symbolic" ) {
      halign = Align.END,
      tooltip_markup = Utils.tooltip_with_accel( _( "View next entry in sidebar" ), "<Control>Right" )
    };
    _next.clicked.connect( action_show_next_entry );
    _next.hide();

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
    tbox.append( _prev );
    tbox.append( _next );
    tbox.append( _burger );

    _date_popover = new Popover() {
      child = create_date_picker()
    };

    /* Add the date */
    _date = new MenuButton() {
      halign       = Align.START,
      // hexpand      = true,
      margin_start = Journaler.settings.get_int( "editor-margin" ),
      margin_top   = 5,
      label        = "",
      popover      = _date_popover,
      has_frame    = false,
      direction    = ArrowType.NONE
    };
    _date.add_css_class( "text-background" );
    _date.activate.connect(() => {
      _cal.year  = _entry.get_year();
      _cal.month = _entry.get_month() - 1;
      _cal.day   = (int)_entry.get_day();
    });

    _time = new Label( "" ) {
      halign  = Align.START,
      hexpand = true,
      margin_top = 5
    };

    var dtbox = new Box( Orientation.HORIZONTAL, 5 );
    dtbox.append( _date );
    dtbox.append( _time );

    /* Add the journal name */
    _jname = new MenuButton() {
      halign = Align.END,
      hexpand = true,
      margin_top = 5,
      margin_end = 5,
      label = "",
      menu_model = new GLib.Menu(),
      has_frame = false,
      direction = ArrowType.NONE
    };
    _jname.add_css_class( "text-background" );

    var dbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign = Align.FILL,
      hexpand = true
    };
    dbox.append( dtbox );
    dbox.append( _jname );

    Idle.add(() => {
      dbox.add_css_class( "text-background" );
      return( false );
    });

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
    append( dbox );
    append( _tags );
    append( sep1 );
    append( _quote_revealer );
    append( _text_stack );
    append( sep2 );
    append( _stats );

    initialize_spell_checker();

  }

  /* Creates the date picker which will allow the user to adjust the date of the entry */
  private Box create_date_picker() {

    var title = new Label( Utils.make_title( _( "Change date" ) ) ) {
      halign = Align.START,
      hexpand = true,
      use_markup = true
    };

    _cal = new Calendar() {
      show_heading = true
    };
    _cal.day_selected.connect(() => {
      var dt    = _cal.get_date();
      var date  = DBEntry.datetime_date( dt );
      var today = DBEntry.todays_date();
      if( !DBEntry.before( today, date ) && (_entry.date != date) ) {
        if( _journal.move_entry( _entry, _journal, date ) ) {
          _entry.date = date;
          entry_moved( _entry );
          Utils.debug_output( "Entry successfully changed to date %s".printf( _entry.date ) );
        }
        _date.label = dt.format( "%A, %B %e, %Y" );
        _date_popover.popdown();
      }
    });

    var box = new Box( Orientation.VERTICAL, 10 ) {
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };
    box.append( title );
    box.append( _cal );

    return( box );

  }

  /* Called whenever the journals change */
  private void journals_changed() {

    var menu = (GLib.Menu)_jname.menu_model;

    menu.remove_all();

    var move_menu = new GLib.Menu();
    menu.append_section( _( "Move to journal" ), move_menu );

    for( int i=0; i<_journals.num_journals(); i++ ) {
      var journal = _journals.get_journal( i );
      if( !journal.hidden ) {
        move_menu.append( journal.name, "textarea.action_change_journal('%s')".printf( journal.name ) );
      }
    }

  }

  /* Moves this journal entry to the given journal */
  private void action_change_journal( SimpleAction action, Variant? variant ) {

    var to_journal = _journals.get_journal_by_name( variant.get_string() );
    if( _journal.move_entry( _entry, to_journal ) ) {
      _entry.journal = to_journal.name;
      entry_moved( _entry );
      Utils.debug_output( "Entry successfully moved to journal %s".printf( to_journal.name ) );
    }

  }

  /* Creates the text viewer when editing an entry */
  private Widget create_text_editor() {

    /* Create image area */
    _image_area = new ImageArea( _win );

    /* Now let's setup some stuff related to the text field */
    var lang_mgr = GtkSource.LanguageManager.get_default();
    var lang     = lang_mgr.get_language( "markdown" );

    /* Create the list of shortcuts */
    var bold_shortcut       = new Shortcut( ShortcutTrigger.parse_string( "<Control>b" ),            ShortcutAction.parse_string( "action(textarea.action_bold_text)" ) );
    var italic_shortcut     = new Shortcut( ShortcutTrigger.parse_string( "<Control>i" ),            ShortcutAction.parse_string( "action(textarea.action_italicize_text)" ) ); 
    var strike_shortcut     = new Shortcut( ShortcutTrigger.parse_string( "<Control>asciitilde" ),   ShortcutAction.parse_string( "action(textarea.action_strike_text)" ) ); 
    var code_shortcut       = new Shortcut( ShortcutTrigger.parse_string( "<Control>m" ),            ShortcutAction.parse_string( "action(textarea.action_code_text)" ) );
    var h1_shortcut         = new Shortcut( ShortcutTrigger.parse_string( "<Control>1" ),            ShortcutAction.parse_string( "action(textarea.action_h1_text)" ) );
    var h2_shortcut         = new Shortcut( ShortcutTrigger.parse_string( "<Control>2" ),            ShortcutAction.parse_string( "action(textarea.action_h2_text)" ) );
    var h3_shortcut         = new Shortcut( ShortcutTrigger.parse_string( "<Control>3" ),            ShortcutAction.parse_string( "action(textarea.action_h3_text)" ) );
    var h4_shortcut         = new Shortcut( ShortcutTrigger.parse_string( "<Control>4" ),            ShortcutAction.parse_string( "action(textarea.action_h4_text)" ) );
    var h5_shortcut         = new Shortcut( ShortcutTrigger.parse_string( "<Control>5" ),            ShortcutAction.parse_string( "action(textarea.action_h5_text)" ) );
    var h6_shortcut         = new Shortcut( ShortcutTrigger.parse_string( "<Control>6" ),            ShortcutAction.parse_string( "action(textarea.action_h6_text)" ) );
    var h1_ul_shortcut      = new Shortcut( ShortcutTrigger.parse_string( "<Control>equal" ),        ShortcutAction.parse_string( "action(textarea.action_h1_ul_text)" ) );
    var h2_ul_shortcut      = new Shortcut( ShortcutTrigger.parse_string( "<Control>minus" ),        ShortcutAction.parse_string( "action(textarea.action_h2_ul_text)" ) );
    var blockquote_shortcut = new Shortcut( ShortcutTrigger.parse_string( "<Control>greater" ),      ShortcutAction.parse_string( "action(textarea.action_blockquote)" ) );
    var hr_shortcut         = new Shortcut( ShortcutTrigger.parse_string( "<Control>h" ),            ShortcutAction.parse_string( "action(textarea.action_hr)" ) );
    var ordered_shortcut    = new Shortcut( ShortcutTrigger.parse_string( "<Control>numbersign" ),   ShortcutAction.parse_string( "action(textarea.action_ordered_list_text)" ) );
    var unordered_shortcut  = new Shortcut( ShortcutTrigger.parse_string( "<Control>asterisk" ),     ShortcutAction.parse_string( "action(textarea.action_unordered_list_text)" ) );
    var task_shortcut       = new Shortcut( ShortcutTrigger.parse_string( "<Control>bracketleft" ),  ShortcutAction.parse_string( "action(textarea.action_task_text)" ) );
    var done_shortcut       = new Shortcut( ShortcutTrigger.parse_string( "<Control>bracketright" ), ShortcutAction.parse_string( "action(textarea.action_task_done_text)" ) );
    var link_shortcut       = new Shortcut( ShortcutTrigger.parse_string( "<Control>k" ),            ShortcutAction.parse_string( "action(textarea.action_link_text)" ) );
    var image_shortcut      = new Shortcut( ShortcutTrigger.parse_string( "<Control><Shift>k" ),     ShortcutAction.parse_string( "action(textarea.action_image_text)" ) );
    var remove_shortcut     = new Shortcut( ShortcutTrigger.parse_string( "<Shift><Control>r" ),     ShortcutAction.parse_string( "action(textarea.action_remove_markup)" ) );

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
    _text.add_shortcut( strike_shortcut );
    _text.add_shortcut( code_shortcut );
    _text.add_shortcut( h1_shortcut );
    _text.add_shortcut( h2_shortcut );
    _text.add_shortcut( h3_shortcut );
    _text.add_shortcut( h4_shortcut );
    _text.add_shortcut( h5_shortcut );
    _text.add_shortcut( h6_shortcut );
    _text.add_shortcut( h1_ul_shortcut );
    _text.add_shortcut( h2_ul_shortcut );
    _text.add_shortcut( blockquote_shortcut );
    _text.add_shortcut( hr_shortcut );
    _text.add_shortcut( ordered_shortcut );
    _text.add_shortcut( unordered_shortcut );
    _text.add_shortcut( task_shortcut );
    _text.add_shortcut( done_shortcut );
    _text.add_shortcut( link_shortcut );
    _text.add_shortcut( image_shortcut );
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
      hscrollbar_policy = PolicyType.NEVER,
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
    formatter_menu.append( "Bold",          "textarea.action_bold_text" );
    formatter_menu.append( "Italicize",     "textarea.action_italicize_text" );
    formatter_menu.append( "Strikethrough", "textarea.action_strike_text" );
    formatter_menu.append( "Monospace",     "textarea.action_code_text" );

    var header_ul_menu = new GLib.Menu();
    header_ul_menu.append( "Header 1 Underline", "textarea.action_h1_ul_text" );
    header_ul_menu.append( "Header 2 Underline", "textarea.action_h2_ul_text" );

    var header_menu = new GLib.Menu();
    header_menu.append( "Header 1", "textarea.action_h1_text" );
    header_menu.append( "Header 2", "textarea.action_h2_text" );
    header_menu.append( "Header 3", "textarea.action_h3_text" );
    header_menu.append( "Header 4", "textarea.action_h4_text" );
    header_menu.append( "Header 5", "textarea.action_h5_text" );
    header_menu.append( "Header 6", "textarea.action_h6_text" );

    var hr_menu = new GLib.Menu();
    hr_menu.append( "Blockquote",      "textarea.action_blockquote" );
    hr_menu.append( "Horizontal Rule", "textarea.action_hr" );

    var list_menu = new GLib.Menu();
    list_menu.append( "Unordered List", "textarea.action_ordered_list_text" );
    list_menu.append( "Ordered List",   "textarea.action_unordered_list_text" );

    var link_menu = new GLib.Menu();
    link_menu.append( "Link",  "textarea.action_link_text" );
    link_menu.append( "Image", "textarea.action_image_text" );

    var task_menu = new GLib.Menu();
    task_menu.append( "Task",      "textarea.action_task_text" );
    task_menu.append( "Task Done", "textarea.action_task_done_text" );

    var deformat_menu = new GLib.Menu();
    deformat_menu.append( "Remove Formatting", "textarea.action_remove_markup" );

    var format_menu = new GLib.Menu();
    format_menu.append_section( null, formatter_menu );
    format_menu.append_section( null, header_ul_menu );
    format_menu.append_section( null, header_menu );
    format_menu.append_section( null, hr_menu );
    format_menu.append_section( null, list_menu );
    format_menu.append_section( null, link_menu );
    format_menu.append_section( null, task_menu );
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

  /* Inserts the given template text at the current insertion cursor location */
  private void action_insert_template( SimpleAction action, Variant? variant ) {
    _win.reset_timer();
    insert_template( variant.get_string() );
  }

  /* Moves the current entry to the trash */
  private void action_trash_entry() {

    _win.reset_timer();

    var journal = _journals.get_journal_by_name( _entry.journal );
    if( journal != null ) {

      /* Save the current entry so that we have _entry up-to-date */
      save();

      if( journal.move_entry( _entry, _journals.trash ) ) {
        entry_moved( _entry );
        Utils.debug_output( "Entry successfully moved to the trash" );
      }

    }

  }

  /* Moves an entry from the trash back to the originating journal */
  private void action_restore_entry() {

    _win.reset_timer();

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
      Utils.debug_output( "Entry successfully restored from trash" );
    }

  }

  /* Permanently delete the entry from the trash */
  private void action_delete_entry() {

    _win.reset_timer();

    if( _journals.trash.db.remove_entry( _entry ) ) {
      entry_moved( _entry );
      Utils.debug_output( "Entry permanently deleted from trash" );
    }

  }

  /* Show the previous entry in the sidebar */
  public void action_show_previous_entry() {
    show_previous_entry();
  }

  /* Show the next entry in the sidebar */
  public void action_show_next_entry() {
    _win.reset_timer();
    show_next_entry();
  }

  /* Adds Markdown bold syntax around selected text */
  private void action_bold_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_bold_text( _text, _buffer );
    _text.grab_focus();
  }

  /* Adds Markdown italic syntax around selected text */
  private void action_italicize_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_italicize_text( _text, _buffer );
    _text.grab_focus();
  }

  /* Adds Markdown strikethrough syntax around selected text */
  private void action_strike_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_strikethrough_text( _text, _buffer );
    _text.grab_focus();
  }

  /* Adds Markdown code syntax around selected text */
  private void action_code_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_code_text( _text, _buffer );
    _text.grab_focus();
  }

  /* Adds Markdown header syntax around selected text */
  private void action_h1_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_header_text( _buffer, 1 );
    _text.grab_focus();
  }

  /* Adds Markdown header syntax around selected text */
  private void action_h2_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_header_text( _buffer, 2 );
    _text.grab_focus();
  }

  /* Adds Markdown header syntax around selected text */
  private void action_h3_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_header_text( _buffer, 3 );
    _text.grab_focus();
  }

  /* Adds Markdown header syntax around selected text */
  private void action_h4_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_header_text( _buffer, 4 );
    _text.grab_focus();
  }

  /* Adds Markdown header syntax around selected text */
  private void action_h5_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_header_text( _buffer, 5 );
    _text.grab_focus();
  }

  /* Adds Markdown header syntax around selected text */
  private void action_h6_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_header_text( _buffer, 6 );
    _text.grab_focus();
  }

  /* Adds a double underline below each line of selected text, converting them to H1 headers */
  private void action_h1_ul_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_h1_ul_text( _buffer );
    _text.grab_focus();
  }

  /* Adds a single underline below each line of selected text, converting them to H2 headers */
  private void action_h2_ul_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_h2_ul_text( _buffer );
    _text.grab_focus();
  }

  /* Adds one level of blockquote at the current line */
  private void action_blockquote() {
    _win.reset_timer();
    MarkdownFuncs.insert_blockquote( _buffer );
    _text.grab_focus();
  }

  /* Adds a horizontal rule at the current line */
  private void action_hr() {
    _win.reset_timer();
    MarkdownFuncs.insert_horizontal_rule( _buffer );
    _text.grab_focus();
  }

  /* Inserts ordered list numbers at the beginning of each non-empty line */
  private void action_ordered_list_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_ordered_list_text( _buffer );
    _text.grab_focus();
  }

  /* Inserts unordered list (-) characters at the beginning of each non-empty line */
  private void action_unordered_list_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_unordered_list_text( _buffer );
    _text.grab_focus();
  }

  /* Inserts incomplete task strings at the beginning of each non-empty line */
  private void action_task_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_task_text( _buffer );
    _text.grab_focus();
  }

  /* Inserts incomplete task strings at the beginning of each non-empty line */
  private void action_task_done_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_task_done_text( _buffer );
    _text.grab_focus();
  }

  /* Inserts link syntax around the selected URI or text */
  private void action_link_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_link_text( _text, _buffer );
    _text.grab_focus();
  }

  /* Inserts image syntax around the selected image URI or text */
  private void action_image_text() {
    _win.reset_timer();
    MarkdownFuncs.insert_image_text( _text, _buffer, _image_area );
    _text.grab_focus();
  }

  /* Removes all markup from the selected area */
  private void action_remove_markup() {
    _win.reset_timer();
    MarkdownFuncs.clear_markup( _buffer );
    _text.grab_focus();
  }

  /* Inserts the given snippet name */
  private bool insert_template( string name ) {
    var snippet = _templates.get_snippet( name );
    if( snippet != null ) {
      TextIter iter;
      _buffer.get_iter_at_mark( out iter, _buffer.get_insert() );
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
      .no-relief {
        border-width: 0px;
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

  /* Returns true if the tags have changed since it was loaded */
  private bool tags_changed() {
    return( _tags.editable && (_tags.tags.load_tag_list() != _entry.tags.load_tag_list()) );
  }

  /* Returns true if the text of the entry has changed since it was loaded */
  private bool text_changed() {
    return( _text.editable && _text.buffer.get_modified() );
  }

  /* Saves the contents of the text area as an entry in the current database */
  public void save( bool image_changed = false ) {

    /* If the text area is not editable or has not changed, there's no need to save */
    if( (_journal == null) || (_entry == null) || (!title_changed() && !_date_changed && !tags_changed() && !_image_area.changed() && !text_changed()) ) {
      return;
    }

    var entry = new DBEntry.with_date( 
      _entry.journal, _title.text, _text.buffer.text, _tags.tags.load_tag_list(), _entry.date, _entry.time
    );

    _image_area.get_images( entry );

    if( _journal.db.save_entry( _journal, entry ) ) {

      if( (_journals.current == _journal) && (_title.text != _entry.text) ) {
        _journals.current_changed( true );
      }

      _entry = entry;
      _text.buffer.set_modified( false );
      _date_changed = false;

      /* Update the goals */
      if( _stats.goal_reached() && !_entry_goal_reached ) {
        _win.goals.mark_achievement( entry.date );
        _entry_goal_reached = true;
      }

      Utils.debug_output( "Saved successfully to journal %s".printf( _journal.name ) );

    }

  }

  /* Sets the entry contents to the given entry, saving the previous contents, if necessary */
  public void set_buffer( DBEntry? entry, bool editable, SelectedEntryPos pos ) {

    /* Save the current buffer before loading a new one */
    save();

    /* Update the burger menu, if necessary */
    if( (_journal == null) || (_journal.is_trash != _journals.current.is_trash) ) {
      _burger.menu_model = create_burger_menu( _journals.current.is_trash );
    }

    _journal = _journals.current;

    if( entry != null ) {
      _entry = entry;
    }

    var enable_ui = editable && !_journal.is_trash && _entry.loaded;

    /* Set the title */
    _title.text      = _entry.title;
    _title.editable  = enable_ui;
    _title.can_focus = enable_ui;
    _title.focusable = enable_ui;

    /* Set the date */
    if( _entry.date == "" ) {
      _date.label = "";
      _time.label = "";
    } else {
      var dt = _entry.datetime();
      _date.label = dt.format( "%A, %B %e, %Y" );
      _time.label = dt.format( "%I:%M %p" );
      _cal.year   = _entry.get_year();
      _cal.month  = _entry.get_month() - 1;
      _cal.day    = (int)_entry.get_day();
    }
    _date.set_sensitive( enable_ui );
    _date_changed = false;

    _jname.label = _journal.name;
    _jname.set_sensitive( enable_ui );

    /* Set the next and previous button state */
    _prev.set_sensitive( pos.prev_sensitivity() );
    _next.set_sensitive( pos.next_sensitivity() );

    if( _win.review_mode ) {
      _title.text = _entry.gen_title();
      _prev.show();
      _next.show();
      // _jname.show();
    } else {
      _prev.hide();
      _next.hide();
      // _jname.hide();
    }

    /* Set the image */
    _image_area.set_images( _journal, _entry );
    _image_area.editable = enable_ui;

    /* Set the tags */
    var avail_tags = new TagList();
    _journal.db.get_all_tags( avail_tags );
    _tags.set_available_tags( avail_tags );
    _tags.add_tags( _entry.tags );
    _tags.update_tags();
    _tags.editable = enable_ui;

    /* Show the quote of the day if the text field is empty */
    if( (_entry.text == "") && Journaler.settings.get_boolean( "enable-quotations" ) && enable_ui ) {
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
      if( (_entry.text != "") || !insert_template( _journals.current.template ) ) {
        _text.buffer.text = _entry.text;
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
      var tags_empty  = _tags.tags.length() == 0;
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

  /* Sets the distraction free mode to the given value and updates the UI. */
  public void set_distraction_free_mode( bool mode ) {

    if( mode ) {
      if( !_text.editable ) {
        _stats.hide();
      }
      if( !_image_area.empty ) {
        _image_area.hide();
      }
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
      if( !_image_area.empty ) {
        _image_area.show();
      }
      if( _win.review_mode ) {
        show_review();
      }
      set_margin( false );
    }

  }

}

