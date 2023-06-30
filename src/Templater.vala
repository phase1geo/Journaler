using Gtk;

public class Templater : Box {

  private Templates        _templates;
  private Template?        _current;
  private MainWindow       _win;
  private Entry            _name;
  private GtkSource.View   _text;
  private GtkSource.Buffer _buffer;
  private Button           _save;
  private Revealer         _del_revealer;
  private int              _text_margin = 20;
  private string           _theme = "cobalt-light";
  private string           _goto_pane = "";

  private const GLib.ActionEntry action_entries[] = {
    { "action_insert_tab_position", action_insert_tab_position },
  };

  /* Default constructor */
  public Templater( MainWindow win, Templates templates ) {

    Object( orientation: Orientation.VERTICAL, spacing: 5 );

    _win       = win;
    _templates = templates;
    _current   = null;

    /* Add the UI components */
    add_name_frame();
    add_text_frame();
    add_button_bar();

    margin_top    = 5;
    margin_bottom = 5;
    margin_start  = 5;
    margin_end    = 5;

    /* Update the theme used by these components */
    update_theme();

    /* Add the menu actions */
    var actions = new SimpleActionGroup();
    actions.add_action_entries( action_entries, this );
    insert_action_group( "templater", actions );

  }

  /* Returns the widget that will receive input focus when this UI is displayed */
  public Widget get_focus_widget() {
    return( _name );
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
      _save.sensitive = (_name.text != "") && ((_name.text != _current.name) || (_buffer.text != _current.text));
    });

    var box = new Box( Orientation.HORIZONTAL, 5 );
    box.append( label );
    box.append( _name );

    var sep = new Separator( Orientation.HORIZONTAL );

    append( box );
    append( sep );

  }

  /* Adds the text frame */
  private void add_text_frame() {

    var line_spacing = 5;

    var lbl = new Label( Utils.make_title( _( "Template Text:" ) ) ) {
      halign     = Align.START,
      xalign     = (float)0,
      use_markup = true
    };

    /* Now let's setup some stuff related to the text field */
    var lang_mgr = GtkSource.LanguageManager.get_default();
    var lang     = lang_mgr.get_language( "markdown" );

    /* Create the text entry view */
    var text_focus = new EventControllerFocus();
    _buffer = new GtkSource.Buffer.with_language( lang );
    _text = new GtkSource.View.with_buffer( _buffer ) {
      valign             = Align.FILL,
      vexpand            = true,
      top_margin         = _text_margin / 2,
      left_margin        = _text_margin,
      bottom_margin      = _text_margin,
      right_margin       = _text_margin,
      wrap_mode          = WrapMode.WORD,
      pixels_below_lines = line_spacing,
      pixels_inside_wrap = line_spacing,
      extra_menu         = create_insertion_menu()
    };
    _text.add_controller( text_focus );
    _text.add_css_class( "journal-text" );
    _buffer.changed.connect(() => {
      _save.sensitive = (_name.text != "") && ((_name.text != _current.name) || (_buffer.text != _current.text));
    });

    var scroll = new ScrolledWindow() {
      vscrollbar_policy = PolicyType.AUTOMATIC,
      child = _text
    };

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

  /* Creates the insertion menu */
  private GLib.Menu create_insertion_menu() {

    var menu = new GLib.Menu();

    menu.append( _( "Insert Tab Position" ), "templater.action_insert_tab_position" );

    return( menu );

  }

  /* Inserts a tab position string */
  private void action_insert_tab_position() {

    var tab_pos = 0;
    var tab_str = "${%d}".printf( tab_pos );

    _buffer.insert_at_cursor( tab_str, tab_str.length );

  }

  /* Sets the theme and CSS classes */
  private void update_theme() {
    var style_mgr = GtkSource.StyleSchemeManager.get_default();
    var style = style_mgr.get_scheme( _theme );
    _buffer.style_scheme = style;
  }

  /* Creates the button bar */
  private void add_button_bar() {

    var del = new Button.with_label( _( "Delete" ) );
    del.clicked.connect(() => {
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
      _win.show_pane( _goto_pane );
    });

    _save = new Button.with_label( _( "Save Changes" ) ) {
      sensitive = false
    };
    _save.clicked.connect(() => {
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

  }

}