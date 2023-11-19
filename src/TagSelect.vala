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

public class TagSelect : Box {

  private MainWindow _win;
  private DropDown   _select;
  private Button     _button;
  private Revealer   _select_revealer;
  private Revealer   _button_revealer;
  private bool       _ignore_select = false;

  /*
  public string text {
    get {
      return( _entry.text );
    }
    set {
      _entry.text = value;
    }
  }
  */

  public signal void activated( string tag );
  public signal void removed( string tag );
  public signal void button_double_clicked( string tag );

  /* Default constructor */
  public class TagSelect( MainWindow win, string tag_text ) {

    Object( orientation: Orientation.VERTICAL, spacing: 0, halign: Align.START, valign: Align.CENTER, vexpand: false );

    _win = win;

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

    /*
    var entry_focus = new EventControllerFocus();
    var entry_key   = new EventControllerKey();
    */
    _select = new DropDown( null, null ) {
      halign     = Gtk.Align.FILL,
      hexpand    = false,
      margin_end = 5
    };
    /*
    _entry.add_controller( entry_focus );
    _entry.add_controller( entry_key );
    */

    _select.notify["selected"].connect(() => {
      if( !_ignore_select ) {
        var string_list = (StringList)_select.model;
        var str = string_list.get_string( _select.get_selected() );
        activated( str );
      }
    });

    /*
    entry_focus.leave.connect(() => {
      if( !_always_shown_when_revealed && (_hide_if_contains_text || (_entry.get_text() == "")) ) {
        hide_entry();
      }
    });
    */

    button_key.key_pressed.connect((keyval, keycode, state) => {
      _win.reset_timer();
      switch( keyval ) {
        case Gdk.Key.Delete    :
        case Gdk.Key.BackSpace :  removed( (string)_select.get_selected_item() );  break;
        case Gdk.Key.Return    :
        case Gdk.Key.space     :  show_select();  break;
        default                :  return( false );
      }
      return( true );
    });

    _button.clicked.connect(() => {
      _win.reset_timer();
      show_select();
    });

    /*
    entry_key.key_released.connect((keyval, keycode, state) => {
      _win.reset_timer();
      if( keyval == Gdk.Key.Escape ) {
        hide_entry();
      }
    });
    */

    _select_revealer = new Gtk.Revealer() {
      valign          = Gtk.Align.CENTER,
      child           = _select,
      reveal_child    = false,
      transition_type = RevealerTransitionType.SLIDE_DOWN
    };

    _button_revealer = new Gtk.Revealer() {
      child           = _button,
      reveal_child    = true,
      transition_type = RevealerTransitionType.SLIDE_DOWN
    };

    append( _select_revealer );
    append( _button_revealer );

  }

  /* Populates the entry completion with the given tags */
  public void populate_completion( Array<string> tags ) {

    var string_list = new Gtk.StringList( null );

    for( int i=0; i<tags.length; i++ ) {
      string_list.append( tags.index( i ) );
    }

    _ignore_select = true;
    _select.set_model( string_list );
    _ignore_select = false;

  }

  /* Displays the text entry field */
  public void show_select() {
    _button_revealer.reveal_child = false;
    _select_revealer.reveal_child  = true;
    // _select.text = "";
    _select.can_focus = true;
    _select.grab_focus();
  }

  /* Hides the text entry field and just shows the tag */
  public void hide_select() {
    _select_revealer.reveal_child = false;
    _button_revealer.reveal_child = true;
    _select.can_focus = false;
    _button.grab_focus();
  }

}
