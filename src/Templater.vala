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

    /* Update the theme used by these components */
    update_theme();

  }

  /* Adds the name frame */
  private void add_name_frame() {

    var label = new Label( Utils.make_title( _( "Template Name (required):" ) ) );

    _name = new Entry() {
      halign  = Align.FILL,
      hexpand = true
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
      pixels_inside_wrap = line_spacing
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

    append( scroll );

  }

  /* Sets the theme and CSS classes */
  private void update_theme() {

    /* Update the text buffer theme */
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

    _del_revealer = new Revealer() {
      child = del,
      reveal_child = false
    };

    var cancel = new Button.with_label( _( "Cancel" ) );
    cancel.clicked.connect(() => {
      _win.show_pane( _goto_pane );
    });

    _save = new Button.with_label( _( "Save Changes" ) );
    _save.clicked.connect(() => {
      _current.name = _name.text;
      _current.text = _buffer.text;
      _templates.add_template( _current );
      _win.show_pane( _goto_pane );
    });

    var rbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign = Align.END
    };
    rbox.append( cancel );
    rbox.append( _save );

    var box = new Box( Orientation.HORIZONTAL, 5 );
    box.append( _del_revealer );
    box.append( rbox );

    append( box );

  }

  /* Sets the current template for editing */
  public void set_current( Template? template, string goto_pane ) {

    _goto_pane = goto_pane;

    if( template == null ) {
      _current = new Template( "", "" );
      _del_revealer.reveal_child = false;
    } else {
      _current = template;
      _del_revealer.reveal_child = true;
    }

    _name.text   = _current.name;
    _buffer.text = _current.text;

  }

}
