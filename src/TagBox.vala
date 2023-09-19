/*
* Copyright (c) 2023 (https://github.com/phase1geo/Journaler)
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

public class TagBox : Box {

  private Journal? _journal = null;
  private DBEntry? _entry = null;

  private MainWindow _win;
  private Box        _box;
  private TagEntry   _new_tag_entry;

  private List<Widget>  _tag_widgets;
  private Array<string> _all_tags;
  private bool          _editable = true;

  public Journal? journal {
    get {
      return( _journal );
    }
    set {
      _journal = value;
    }
  }

  public DBEntry? entry {
    get {
      return( _entry );
    }
    set {
      _entry = value;
      update_tags();
    }
  }

  public bool editable {
    get {
      return( _editable );
    }
    set {
      if( _editable != value ) {
        _editable = value;
        if( _editable ) {
          _new_tag_entry.show();
        } else {
          _new_tag_entry.hide();
        }
      }
    }
  }

  /* Default constructor */
  public TagBox( MainWindow win ) {

    Object( orientation: Orientation.VERTICAL, spacing: 0 );

    _win         = win;
    _tag_widgets = new List<Widget>();
    _all_tags    = new Array<string>();

    _new_tag_entry = new TagEntry( _win, _("Click to add tag…") ) {
      add_css = false
    };
    _new_tag_entry.activated.connect((tag) => {
      _win.reset_timer();
      _entry.add_tag( tag );
      update_tags();
    });

    _box = new Box( Orientation.HORIZONTAL, 5 ) {
      valign = Align.CENTER
    };
    _box.append( new Gtk.Image.from_icon_name( "tag-symbolic" ) );
    _box.append( _new_tag_entry );

    var scroller = new ScrolledWindow() {
      hexpand = true,
      valign  = Align.CENTER
    };
    scroller.child = _box;
    scroller.scroll_child.connect((t,h) => {
      _win.reset_timer();
      return( false );
    });

    append( scroller );

  }

  /* This should be called whenever the tags change in _entry */
  public void update_tags() {

    /* Refresh the completion data */
    refresh_completion();

    /* Redraw the tags in the UI */
    redraw_tags();

    /* Update the database with the entry changes */
    _journal.db.save_tags_only( _entry );

  }

  /* Updates the completion UI */
  private void refresh_completion () {

    /* Clear the current tags */
    _all_tags.remove_range( 0, _all_tags.length );

    /* Get the tags from the database */
    _journal.db.get_all_tags( _all_tags );

    /* Remove any tags that are currently set for this entry */
    for( int i=(int)(_all_tags.length - 1); i>=0; i-- ) {
      if( (_entry != null) && _entry.contains_tag( _all_tags.index( i ) ) ) {
        _all_tags.remove_index( i );
      }
    }

  }

  /* Redraws the tags */
  private void redraw_tags() {

    /* Delete the tags from the box */
    _box.remove( _new_tag_entry );
    _tag_widgets.foreach((tag_widget) => {
      _box.remove( tag_widget );
      _tag_widgets.remove( tag_widget );
      tag_widget.destroy();
    });

    if( _entry == null ) {
      return;
    }

    foreach( var tag in _entry.tags ) {

      var tag_motion = new EventControllerMotion();
      var tag_key    = new EventControllerKey();
      var tag_button = new Entry() {
        text            = tag,
        editable        = false,
        has_frame       = false,
        max_width_chars = tag.char_count(),
        width_chars     = tag.char_count(),
        secondary_icon_name = ""
      };
      tag_button.add_css_class( "tags" );
      tag_button.add_controller( tag_motion );
      tag_button.add_controller( tag_key );

      tag_button.icon_release.connect((pos) => {
        _win.reset_timer();
        remove_tag( tag_button, tag );
      });

      tag_motion.enter.connect((x,y) => {
        _win.reset_timer();
        tag_button.secondary_icon_name = "window-close-symbolic";
      });
      tag_motion.leave.connect(() => {
        _win.reset_timer();
        tag_button.secondary_icon_name = "";
      });

      tag_key.key_pressed.connect((keyval, keycode, state) => {
        _win.reset_timer();
        if( (keyval == Gdk.Key.Delete) || (keyval == Gdk.Key.BackSpace) ) {
          remove_tag( tag_button, tag );
          return( false );
        }
        return( true );
      });

      /*
      tag_button.clicked.connect(() => {
        _win.reset_timer();
        remove_tag( tag_button, tag );
      });
      */

      _box.append( tag_button );
      _tag_widgets.append( tag_button );

    }

    _new_tag_entry.populate_completion( _all_tags );
    _new_tag_entry.hide_entry();
    _new_tag_entry.text = "";

    _box.append( _new_tag_entry );

  }

  private void remove_tag( Widget btn, string tag ) {
    _entry.remove_tag( tag );
    _journal.db.save_tags_only( _entry );
    _box.remove( btn );
    _tag_widgets.remove( btn );
    btn.destroy();
  }

  public void add_class( string name ) {
    add_css_class( name );
  }

  public void remove_class( string name ) {
    remove_css_class( name );
  }

}
