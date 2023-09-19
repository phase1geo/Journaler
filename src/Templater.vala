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

public enum TemplateVariable {
  CURRENT_YEAR,
  CURRENT_YEAR_SHORT,
  CURRENT_MONTH,
  CURRENT_MONTH_NAME,
  CURRENT_MONTH_NAME_SHORT,
  CURRENT_DATE,
  CURRENT_DAY_NAME,
  CURRENT_DAY_NAME_SHORT,
  CURRENT_HOUR,
  CURRENT_MINUTE,
  CURRENT_SECOND,
  CURRENT_SECONDS_UNIX,
  NAME_SHORT,
  NAME,
  TM_CURRENT_LINE,
  TM_LINE_INDEX,
  TM_LINE_NUMBER,
  NUM;

  public string to_string() {
    switch( this ) {
      case CURRENT_YEAR             :  return( "CURRENT_YEAR" );
      case CURRENT_YEAR_SHORT       :  return( "CURRENT_YEAR_SHORT" );
      case CURRENT_MONTH            :  return( "CURRENT_MONTH" );
      case CURRENT_MONTH_NAME       :  return( "CURRENT_MONTH_NAME" );
      case CURRENT_MONTH_NAME_SHORT :  return( "CURRENT_MONTH_NAME_SHORT" );
      case CURRENT_DATE             :  return( "CURRENT_DATE" );
      case CURRENT_DAY_NAME         :  return( "CURRENT_DAY_NAME" );
      case CURRENT_DAY_NAME_SHORT   :  return( "CURRENT_DAY_NAME_SHORT" );
      case CURRENT_HOUR             :  return( "CURRENT_HOUR" );
      case CURRENT_MINUTE           :  return( "CURRENT_MINUTE" );
      case CURRENT_SECOND           :  return( "CURRENT_SECOND" );
      case CURRENT_SECONDS_UNIX     :  return( "CURRENT_SECONDS_UNIX" );
      case NAME_SHORT               :  return( "NAME_SHORT" );
      case NAME                     :  return( "NAME" );
      case TM_CURRENT_LINE          :  return( "TM_CURRENT_LINE" );
      case TM_LINE_INDEX            :  return( "TM_LINE_INDEX" );
      case TM_LINE_NUMBER           :  return( "TM_LINE_NUMBER" );
      default                       :  assert_not_reached();
    }
  }

  public string label() {
    switch( this ) {
      case CURRENT_YEAR             :  return( _( "Year, four digits" ) );
      case CURRENT_YEAR_SHORT       :  return( _( "Year, last two digits" ) );
      case CURRENT_MONTH            :  return( _( "Month, 01-12" ) );
      case CURRENT_MONTH_NAME       :  return( _( "Month, full name" ) );
      case CURRENT_MONTH_NAME_SHORT :  return( _( "Month, abbreviated name" ) );
      case CURRENT_DATE             :  return( _( "Day of month, 1-31" ) );
      case CURRENT_DAY_NAME         :  return( _( "Day of week, full name" ) );
      case CURRENT_DAY_NAME_SHORT   :  return( _( "Day of week, abbreviated name" ) );
      case CURRENT_HOUR             :  return( _( "Hour, 24-hour format" ) );
      case CURRENT_MINUTE           :  return( _( "Minute, in hour" ) );
      case CURRENT_SECOND           :  return( _( "Second, in minute" ) );
      case CURRENT_SECONDS_UNIX     :  return( _( "Seconds since UNIX epoch" ) );
      case NAME_SHORT               :  return( _( "User, login name" ) );
      case NAME                     :  return( _( "User, full name" ) );
      case TM_CURRENT_LINE          :  return( _( "Contents of current line" ) );
      case TM_LINE_INDEX            :  return( _( "Zero-index line number" ) );
      case TM_LINE_NUMBER           :  return( _( "One-index line number" ) );
      default                       :  assert_not_reached();
    }

  }

}

public enum TransformFunction {
  LOWER,
  UPPER,
  CAPITALIZE,
  UNCAPITALIZE,
  HTML,
  CAMELIZE,
  FUNCTIFY,
  NAMESPACE,
  CLASS,
  INSTANCE,
  SPACE,
  STRIPSUFFIX,
  SLASHTODOTS,
  DESCENDPATH,
  NUM;

  public string to_string() {
    switch( this ) {
      case LOWER        :  return( "lower" );
      case UPPER        :  return( "upper" );
      case CAPITALIZE   :  return( "capitalize" );
      case UNCAPITALIZE :  return( "uncapitalize" );
      case HTML         :  return( "html" );
      case CAMELIZE     :  return( "camelize" );
      case FUNCTIFY     :  return( "functify" );
      case NAMESPACE    :  return( "namespace" );
      case CLASS        :  return( "class" );
      case INSTANCE     :  return( "instance" );
      case SPACE        :  return( "space" );
      case STRIPSUFFIX  :  return( "stripsuffix" );
      case SLASHTODOTS  :  return( "slash_to_dots" );
      case DESCENDPATH  :  return( "descend_path" );
      default           :  assert_not_reached();
    }
  }

  public string label() {
    switch( this ) {
      case LOWER        :  return( _( "Lower-case" ) );
      case UPPER        :  return( _( "Upper-case" ) );
      case CAPITALIZE   :  return( _( "Capitalize" ) );
      case UNCAPITALIZE :  return( _( "Remove capitalization" ) );
      case HTML         :  return( _( "Convert special HTML characters" ) );
      case CAMELIZE     :  return( _( "Camel-case" ) );
      case FUNCTIFY     :  return( _( "Snake-case" ) );
      case NAMESPACE    :  return( _( "Use namespace name" ) );
      case CLASS        :  return( _( "Use class name" ) );
      case INSTANCE     :  return( _( "Use instance name" ) );
      case SPACE        :  return( _( "Convert all characters to spaces" ) );
      case STRIPSUFFIX  :  return( _( "Remove the filename suffix" ) );
      case SLASHTODOTS  :  return( _( "Convert slashes to dots" ) );
      case DESCENDPATH  :  return( _( "Remove parent directory" ) );
      default           :  assert_not_reached();
    }
  }

}

public class Templater : Box {

  private Templates        _templates;
  private Template?        _current;
  private MainWindow       _win;
  private ImageArea        _imager;
  private Entry            _name;
  private GtkSource.View   _text;
  private GtkSource.Buffer _buffer;
  private Button           _save;
  private Revealer         _del_revealer;
  private GLib.Menu        _var_menu;
  private string           _goto_pane = "";
  private int              _tab_pos = 1;

  private const GLib.ActionEntry action_entries[] = {
    { "action_insert_next_tab_position", action_insert_next_tab_position },
    { "action_insert_last_tab_position", action_insert_last_tab_position },
    { "action_insert_string",            action_insert_string, "s" },
    { "action_bold_text",                action_bold_text },
    { "action_italicize_text",           action_italicize_text },
    { "action_strike_text",              action_strike_text },
    { "action_code_text",                action_code_text },
    { "action_h1_text",                  action_h1_text },
    { "action_h2_text",                  action_h2_text },
    { "action_h3_text",                  action_h3_text },
    { "action_h4_text",                  action_h4_text },
    { "action_h5_text",                  action_h5_text },
    { "action_h6_text",                  action_h6_text },
    { "action_h1_ul_text",               action_h1_ul_text },
    { "action_h2_ul_text",               action_h2_ul_text },
    { "action_blockquote",               action_blockquote },
    { "action_hr",                       action_hr },
    { "action_ordered_list_text",        action_ordered_list_text },
    { "action_unordered_list_text",      action_unordered_list_text },
    { "action_task_text",                action_task_text },
    { "action_task_done_text",           action_task_done_text },
    { "action_link_text",                action_link_text },
    { "action_image_text",               action_image_text },
    { "action_remove_markup",            action_remove_markup },
  };

  /* Default constructor */
  public Templater( Gtk.Application app, MainWindow win, ImageArea imager, Templates templates ) {

    Object( orientation: Orientation.VERTICAL, spacing: 5 );

    _win       = win;
    _imager    = imager;
    _templates = templates;
    _current   = null;

    _templates.template_vars.changed.connect(() => {
      update_insert_var_menu();
    });

    /* Add the UI components */
    add_name_frame();
    add_text_frame();
    add_button_bar();

    margin_top    = 5;
    margin_bottom = 5;
    margin_start  = 5;
    margin_end    = 5;

    /* Update the theme used by these components */
    win.themes.theme_changed.connect((name) => {
      update_theme( name );
    });
    Journaler.settings.changed.connect((key) => {
      switch( key ) {
        case "editor-margin"       :  set_margin();        break;
        case "editor-line-spacing" :  set_line_spacing();  break;
      }
    });

    /* Add the menu actions */
    var actions = new SimpleActionGroup();
    actions.add_action_entries( action_entries, this );
    insert_action_group( "templater", actions );

    /* Add keyboard shortcuts */
    add_keyboard_shortcuts( app );

  }

  /* Returns the widget that will receive input focus when this UI is displayed */
  public Widget get_focus_widget() {
    return( _name );
  }

  /* Add keyboard shortcuts */
  private void add_keyboard_shortcuts( Gtk.Application app ) {

    app.set_accels_for_action( "templater.action_bold_text",           { "<Control>b" } );
    app.set_accels_for_action( "templater.action_italicize_text",      { "<Control>i" } );
    app.set_accels_for_action( "templater.action_strike_text",         { "<Control>asciitilde" } );
    app.set_accels_for_action( "templater.action_code_text",           { "<Control>m" } );
    app.set_accels_for_action( "templater.action_h1_text",             { "<Control>1" } );
    app.set_accels_for_action( "templater.action_h2_text",             { "<Control>2" } );
    app.set_accels_for_action( "templater.action_h3_text",             { "<Control>3" } );
    app.set_accels_for_action( "templater.action_h4_text",             { "<Control>4" } );
    app.set_accels_for_action( "templater.action_h5_text",             { "<Control>5" } );
    app.set_accels_for_action( "templater.action_h6_text",             { "<Control>6" } );
    app.set_accels_for_action( "templater.action_h1_ul_text",          { "<Control>equal" } );
    app.set_accels_for_action( "templater.action_h2_ul_text",          { "<Control>minus" } );
    app.set_accels_for_action( "templater.action_blockquote",          { "<Control>greater" } );
    app.set_accels_for_action( "templater.action_hr",                  { "<Control>h" } );
    app.set_accels_for_action( "templater.action_ordered_list_text",   { "<Control>numbersign" } );
    app.set_accels_for_action( "templater.action_unordered_list_text", { "<Control>asterisk" } );
    app.set_accels_for_action( "templater.action_task_text",           { "<Control>bracketleft" } );
    app.set_accels_for_action( "templater.action_task_done_text",      { "<Control>bracketright" } );
    app.set_accels_for_action( "templater.action_link_text",           { "<Control>k" } );
    app.set_accels_for_action( "templater.action_image_text",          { "<Control><Shift>k" } );
    app.set_accels_for_action( "templater.action_remove_markup",       { "<Control><Shift>r" } );

  }

  /* Adds the name frame */
  private void add_name_frame() {

    var label = new Label( Utils.make_title( _( "Template Name:" ) ) ) {
      use_markup = true
    };

    _name = new Entry() {
      halign  = Align.FILL,
      hexpand = true,
      placeholder_text = _( "Required" )
    };
    _name.changed.connect(() => {
      _win.reset_timer();
      _save.sensitive = (_name.text != "") && ((_name.text != _current.name) || (_buffer.text != _current.text));
    });

    var box = new Box( Orientation.HORIZONTAL, 5 );
    box.append( label );
    box.append( _name );

    var sep = new Separator( Orientation.HORIZONTAL );

    append( box );
    append( sep );

  }
  
  /* Sets the margin for the text widget */
  private void set_margin() {
  
    var margin = Journaler.settings.get_int( "editor-margin" );
    
    _text.top_margin    = margin / 2;
    _text.left_margin   = margin;
    _text.bottom_margin = margin;
    _text.right_margin  = margin;
  
  }
  
  /* Sets the line spacing for the text widget */
  private void set_line_spacing() {
  
    var line_spacing = Journaler.settings.get_int( "editor-line-spacing" );
    
    _text.pixels_below_lines = line_spacing;
    _text.pixels_inside_wrap = line_spacing;
    
  }

  /* Adds the text frame */
  private void add_text_frame() {

    var lbl = new Label( Utils.make_title( _( "Template Text:" ) ) ) {
      halign     = Align.START,
      xalign     = (float)0,
      use_markup = true
    };

    /* Now let's setup some stuff related to the text field */
    var lang_mgr = GtkSource.LanguageManager.get_default();
    var lang     = lang_mgr.get_language( "markdown" );

    /* Create the list of shortcuts */
    var bold_shortcut       = new Shortcut( ShortcutTrigger.parse_string( "<Control>b" ),            ShortcutAction.parse_string( "action(templater.action_bold_text)" ) );
    var italic_shortcut     = new Shortcut( ShortcutTrigger.parse_string( "<Control>i" ),            ShortcutAction.parse_string( "action(templater.action_italicize_text)" ) );
    var strike_shortcut     = new Shortcut( ShortcutTrigger.parse_string( "<Control>asciitilde" ),   ShortcutAction.parse_string( "action(templater.action_strike_text)" ) );
    var code_shortcut       = new Shortcut( ShortcutTrigger.parse_string( "<Control>m" ),            ShortcutAction.parse_string( "action(templater.action_code_text)" ) );
    var h1_shortcut         = new Shortcut( ShortcutTrigger.parse_string( "<Control>1" ),            ShortcutAction.parse_string( "action(templater.action_h1_text)" ) );
    var h2_shortcut         = new Shortcut( ShortcutTrigger.parse_string( "<Control>2" ),            ShortcutAction.parse_string( "action(templater.action_h2_text)" ) );
    var h3_shortcut         = new Shortcut( ShortcutTrigger.parse_string( "<Control>3" ),            ShortcutAction.parse_string( "action(templater.action_h3_text)" ) );
    var h4_shortcut         = new Shortcut( ShortcutTrigger.parse_string( "<Control>4" ),            ShortcutAction.parse_string( "action(templater.action_h4_text)" ) );
    var h5_shortcut         = new Shortcut( ShortcutTrigger.parse_string( "<Control>5" ),            ShortcutAction.parse_string( "action(templater.action_h5_text)" ) );
    var h6_shortcut         = new Shortcut( ShortcutTrigger.parse_string( "<Control>6" ),            ShortcutAction.parse_string( "action(templater.action_h6_text)" ) );
    var h1_ul_shortcut      = new Shortcut( ShortcutTrigger.parse_string( "<Control>equal" ),        ShortcutAction.parse_string( "action(templater.action_h1_ul_text)" ) );
    var h2_ul_shortcut      = new Shortcut( ShortcutTrigger.parse_string( "<Control>minus" ),        ShortcutAction.parse_string( "action(templater.action_h2_ul_text)" ) );
    var blockquote_shortcut = new Shortcut( ShortcutTrigger.parse_string( "<Control>greater" ),      ShortcutAction.parse_string( "action(templater.action_blockquote)" ) );
    var hr_shortcut         = new Shortcut( ShortcutTrigger.parse_string( "<Control>h" ),            ShortcutAction.parse_string( "action(templater.action_hr)" ) );
    var ordered_shortcut    = new Shortcut( ShortcutTrigger.parse_string( "<Control>numbersign" ),   ShortcutAction.parse_string( "action(templater.action_ordered_list_text)" ) );
    var unordered_shortcut  = new Shortcut( ShortcutTrigger.parse_string( "<Control>asterisk" ),     ShortcutAction.parse_string( "action(templater.action_unordered_list_text)" ) );
    var task_shortcut       = new Shortcut( ShortcutTrigger.parse_string( "<Control>bracketleft" ),  ShortcutAction.parse_string( "action(templater.action_task_text)" ) );
    var done_shortcut       = new Shortcut( ShortcutTrigger.parse_string( "<Control>bracketright" ), ShortcutAction.parse_string( "action(templater.action_task_done_text)" ) );
    var link_shortcut       = new Shortcut( ShortcutTrigger.parse_string( "<Control>k" ),            ShortcutAction.parse_string( "action(templater.action_link_text)" ) );
    var image_shortcut      = new Shortcut( ShortcutTrigger.parse_string( "<Control><Shift>k" ),     ShortcutAction.parse_string( "action(templater.action_image_text)" ) );
    var remove_shortcut     = new Shortcut( ShortcutTrigger.parse_string( "<Shift><Control>r" ),     ShortcutAction.parse_string( "action(templater.action_remove_markup)" ) );

    /* Create the text entry view */
    var text_focus = new EventControllerFocus();
    _buffer = new GtkSource.Buffer.with_language( lang );
    _text = new GtkSource.View.with_buffer( _buffer ) {
      valign     = Align.FILL,
      vexpand    = true,
      wrap_mode  = WrapMode.WORD,
      extra_menu = create_extra_menu()
    };
    _text.add_controller( text_focus );
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
    
    set_margin();
    set_line_spacing();
    
    _buffer.changed.connect(() => {
      _win.reset_timer();
      _save.sensitive = (_name.text != "") && ((_name.text != _current.name) || (_buffer.text != _current.text));
    });

    var scroll = new ScrolledWindow() {
      vscrollbar_policy = PolicyType.AUTOMATIC,
      child = _text
    };
    scroll.scroll_child.connect((t,h) => {
      _win.reset_timer();
      return( true );
    });

    var box = new Box( Orientation.VERTICAL, 5 ) {
      halign  = Align.FILL,
      valign  = Align.FILL,
      hexpand = true,
      vexpand = true
    };
    box.append( lbl );
    box.append( scroll );

    append( box );

  }

  /* Creates the text formatting submenu */
  private GLib.Menu create_format_menu() {

    var formatter_menu = new GLib.Menu();
    formatter_menu.append( "Bold",          "templater.action_bold_text" );
    formatter_menu.append( "Italicize",     "templater.action_italicize_text" );
    formatter_menu.append( "Strikethrough", "templater.action_strike_text" );
    formatter_menu.append( "Monospace",     "templater.action_code_text" );

    var header_ul_menu = new GLib.Menu();
    header_ul_menu.append( "Header 1 Underline", "templater.action_h1_ul_text" );
    header_ul_menu.append( "Header 2 Underline", "templater.action_h2_ul_text" );

    var header_menu = new GLib.Menu();
    header_menu.append( "Header 1", "templater.action_h1_text" );
    header_menu.append( "Header 2", "templater.action_h2_text" );
    header_menu.append( "Header 3", "templater.action_h3_text" );
    header_menu.append( "Header 4", "templater.action_h4_text" );
    header_menu.append( "Header 5", "templater.action_h5_text" );
    header_menu.append( "Header 6", "templater.action_h6_text" );

    var hr_menu = new GLib.Menu();
    hr_menu.append( "Blockquote",      "templater.action_blockquote" );
    hr_menu.append( "Horizontal Rule", "templater.action_hr" );

    var list_menu = new GLib.Menu();
    list_menu.append( "Unordered List", "templater.action_ordered_list_text" );
    list_menu.append( "Ordered List",   "templater.action_unordered_list_text" );

    var link_menu = new GLib.Menu();
    link_menu.append( "Link",  "templater.action_link_text" );
    link_menu.append( "Image", "templater.action_image_text" );

    var task_menu = new GLib.Menu();
    task_menu.append( "Task",      "templater.action_task_text" );
    task_menu.append( "Task Done", "templater.action_task_done_text" );

    var deformat_menu = new GLib.Menu();
    deformat_menu.append( "Remove Formatting", "templater.action_remove_markup" );

    var format_menu = new GLib.Menu();
    format_menu.append_section( null, formatter_menu );
    format_menu.append_section( null, header_ul_menu );
    format_menu.append_section( null, header_menu );
    format_menu.append_section( null, hr_menu );
    format_menu.append_section( null, list_menu );
    format_menu.append_section( null, link_menu );
    format_menu.append_section( null, task_menu );
    format_menu.append_section( null, deformat_menu );

    return( format_menu );

  }

  /* Creates the insertion submenu */
  private GLib.Menu create_insertion_menu() {

    var tab_menu = new GLib.Menu();
    tab_menu.append( _( "Insert Next Tab Position" ), "templater.action_insert_next_tab_position" );
    tab_menu.append( _( "Insert Last Tab Position" ), "templater.action_insert_last_tab_position" );

    var var_menu = new GLib.Menu();
    for( int i=0; i<TemplateVariable.NUM; i++ ) {
      var template_var = (TemplateVariable)i;
      var_menu.append( template_var.label(), "templater.action_insert_string('$%s')".printf( template_var.to_string() ) );
    }

    _var_menu = new GLib.Menu();

    var vars_submenu = new GLib.Menu();
    vars_submenu.append_section( null, var_menu );
    vars_submenu.append_section( null, _var_menu );

    var vars_menu = new GLib.Menu();
    vars_menu.append_submenu( _( "Insert Variable" ), vars_submenu );

    var transform_submenu = new GLib.Menu();
    for( int i=0; i<TransformFunction.NUM; i++ ) {
      var transform_func = (TransformFunction)i;
      transform_submenu.append( transform_func.label(), "templater.action_insert_string('%s')".printf( transform_func.to_string() ) );
    }

    var transform_menu = new GLib.Menu();
    transform_menu.append_submenu( _( "Insert Transform Function" ), transform_submenu );

    var ins_menu = new GLib.Menu();
    ins_menu.append_section( null, tab_menu );
    ins_menu.append_section( null, vars_menu );
    ins_menu.append_section( null, transform_menu );

    return( ins_menu );

  }

  /* Returns the extra menu that is appended to the TextView contextual menu */
  private GLib.Menu create_extra_menu() {

    var format = new GLib.Menu();
    format.append_submenu( _( "Format Text" ), create_format_menu() );

    var extra = new GLib.Menu();
    extra.append_submenu( _( "Insert Snippet Syntax" ), create_insertion_menu() );
    extra.append_section( null, format );

    return( extra );

  }

  /* Updates the insertion variable menu */
  public void update_insert_var_menu() {

    for( int i=0; i<_templates.template_vars.num_variables(); i++ ) {
      var variable = _templates.template_vars.get_variable( i );
      _var_menu.append( _( "Insert %s" ).printf( variable.replace( "_", " " ).down() ), "templater.action_insert_string('$%s')".printf( variable ) );
    }

  }

  /* Inserts the given text */
  private void insert_text( string text ) {
    _buffer.insert_at_cursor( text, text.length );
    _text.grab_focus();
  }

  /* Inserts a tab position string */
  private void action_insert_next_tab_position() {
    _win.reset_timer();
    insert_text( "${%d}".printf( _tab_pos++ ) );
  }

  /* Inserts the last tab position */
  private void action_insert_last_tab_position() {
    _win.reset_timer();
    insert_text( "${0}" );
  }

  /* Inserts the given variable */
  private void action_insert_string( SimpleAction action, Variant? variant ) {
    _win.reset_timer();
    insert_text( variant.get_string() );
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

  /* Adds a horizontal rule at the current line */
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
    MarkdownFuncs.insert_image_text( _text, _buffer, _imager );
    _text.grab_focus();
  }

  /* Removes all markup from the selected area */
  private void action_remove_markup() {
    _win.reset_timer();
    MarkdownFuncs.clear_markup( _buffer );
    _text.grab_focus();
  }

  /* Sets the theme and CSS classes */
  private void update_theme( string theme ) {
    var style_mgr = GtkSource.StyleSchemeManager.get_default();
    var style = style_mgr.get_scheme( theme );
    _buffer.style_scheme = style;
  }

  /* Creates the button bar */
  private void add_button_bar() {

    var del = new Button.with_label( _( "Delete" ) );
    del.clicked.connect(() => {
      _win.reset_timer();
      _templates.remove_template( _current.name );
      _win.show_pane( _goto_pane );
    });
    del.add_css_class( "destructive-action" );

    _del_revealer = new Revealer() {
      child = del,
      reveal_child = false
    };

    var cancel = new Button.with_label( _( "Cancel" ) );
    cancel.clicked.connect(() => {
      _win.reset_timer();
      _win.show_pane( _goto_pane );
    });

    _save = new Button.with_label( _( "Save Changes" ) ) {
      sensitive = false
    };
    _save.clicked.connect(() => {
      _win.reset_timer();
      _current.name = _name.text;
      _current.text = _buffer.text;
      _templates.add_template( _current );
      _win.show_pane( _goto_pane );
    });
    _save.add_css_class( "suggested-action" );

    var rbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign  = Align.END,
      hexpand = true
    };
    rbox.append( cancel );
    rbox.append( _save );

    var box = new Box( Orientation.HORIZONTAL, 5 ) {
      halign       = Align.FILL,
      hexpand      = true,
      margin_start = 5,
      margin_end   = 5
    };
    box.append( _del_revealer );
    box.append( rbox );

    append( box );

  }

  private int get_last_tab_pos() {

    try {
      var re  = new Regex( """\${(\d+)""" );
      var max = 0;
      MatchInfo match;

      if( re.match( _buffer.text, 0, out match ) ) {
        do {
          var num = int.parse( match.fetch( 1 ) );
          if( num > max ) {
            max = num;
          }
        } while( match.next() );
      }
      return( max + 1 );
    } catch( RegexError e ) {
      stderr.printf( "ERROR: %s\n", e.message );
    }

    return( 1 );

  }

  /* Sets the current template for editing.  We need to call this prior to showing this pane in the UI. */
  public void set_current( string? name = null ) {

    var template = _templates.find_by_name( name ?? "" );

    if( template == null ) {
      _current = new Template( "", "" );
      _del_revealer.reveal_child = false;
    } else {
      _current = template;
      _del_revealer.reveal_child = true;
    }

    _name.text   = _current.name;
    _buffer.text = _current.text;
    _goto_pane   = _win.get_current_pane();
    _tab_pos     = get_last_tab_pos();

  }

}
