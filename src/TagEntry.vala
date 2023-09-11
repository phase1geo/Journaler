using Gtk;

public class TagEntry : Box {

  private MainWindow _win;
  private Entry      _entry;
  private Button     _button;
  private Revealer   _entry_revealer;
  private Revealer   _button_revealer;

  private bool _hide_if_contains_text = false;
  private bool _always_shown_when_revealed = false;
  private bool _add_css = true;

  public string text {
    get {
      return( _entry.text );
    }
    set {
      _entry.text = value;
    }
  }

  public bool add_css {
    get {
      return( _add_css );
    }
    set {
      _add_css = value;
      if( _add_css ) {
        _button.add_css_class( "tags" );
        _button.set_tooltip_markup( "" );
      } else {
        _button.remove_css_class( "tags" );
        _button.set_tooltip_markup( _("Add Tag") );
      }
    }
  }

  public signal void activated( string tag );
  public signal void removed( string tag );
  public signal void button_double_clicked( string tag );

  /* Default constructor */
  public class TagEntry( MainWindow win, string tag_text ) {

    Object( orientation: Orientation.VERTICAL, spacing: 0, halign: Align.START, valign: Align.CENTER, vexpand: false );

    _win                        = win;
    _always_shown_when_revealed = true;

    var button_key = new EventControllerKey();
    var button_click = new GestureClick();
    _button = new Button() {
      label     = tag_text,
      can_focus = true,
      sensitive = true
    };
    _button.add_controller( button_key );
    _button.add_controller( button_click );
    _button.add_css_class( "tags" );
    _button.get_style_context().add_class( "flat" );

    var completion = new EntryCompletion() {
      text_column        = 0,
      popup_completion   = true,
      popup_set_width    = true,
      popup_single_match = true,
      minimum_key_length = 1
    };

    var entry_focus = new EventControllerFocus();
    var entry_key   = new EventControllerKey();
    _entry = new Entry() {
      halign          = Gtk.Align.FILL,
      max_width_chars = 30,
      margin_end      = 5,
      show_emoji_icon = true,
      max_width_chars = 3,
      width_chars     = 1,
      hexpand         = false,
      completion      = completion
    };
    _entry.add_controller( entry_focus );
    _entry.add_controller( entry_key );

    _entry.activate.connect(() => {
      activated( _entry.text );
    });

    entry_focus.leave.connect(() => {
      if( !_always_shown_when_revealed && (_hide_if_contains_text || (_entry.get_text () == "")) ) {
        hide_entry();
      }
    });

    button_key.key_pressed.connect((keyval, keycode, state) => {
      _win.reset_timer();
      switch( keyval ) {
        case Gdk.Key.Delete    :
        case Gdk.Key.BackSpace :  removed( _entry.text );  break;
        case Gdk.Key.Return    :
        case Gdk.Key.space     :  show_entry();  break;
        default                :  return( false );
      }
      return( true );
    });

    _button.clicked.connect(() => {
      _win.reset_timer();
      if( _add_css ) {
        _button.grab_focus();
      } else {
        show_entry();
      }
    });

    entry_key.key_released.connect((keyval, keycode, state) => {
      _win.reset_timer();
      if( keyval == Gdk.Key.Escape ) {
        hide_entry();
      }
    });

    _entry_revealer = new Gtk.Revealer() {
      valign          = Gtk.Align.CENTER,
      child           = _entry,
      reveal_child    = false,
      transition_type = RevealerTransitionType.SLIDE_DOWN
    };

    _button_revealer = new Gtk.Revealer() {
      child           = _button,
      reveal_child    = true,
      transition_type = RevealerTransitionType.SLIDE_DOWN
    };

    append( _entry_revealer );
    append( _button_revealer );

  }

  /* Populates the entry completion with the given tags */
  public void populate_completion( Array<string> tags ) {

    TreeIter iter;

    var list_store = new Gtk.ListStore( 1, typeof(string) );
    _entry.completion.set_model( list_store );

    for( int i=0; i<tags.length; i++ ) {
      list_store.append( out iter );
      list_store.set( iter, 0, tags.index( i ) );
    }

  }

  /* Displays the text entry field */
  public void show_entry() {
    _button_revealer.reveal_child = false;
    _entry_revealer.reveal_child  = true;
    _entry.text = "";
    _entry.can_focus = true;
    _entry.grab_focus();
  }

  /* Hides the text entry field and just shows the tag */
  public void hide_entry () {
    _entry_revealer.reveal_child = false;
    _button_revealer.reveal_child = true;
    _entry.can_focus = false;
    _button.grab_focus();
  }

}
