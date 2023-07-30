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

public class ImageArea : Box {

  private MainWindow               _win;
  private Paned                    _pane;
  private ScrolledWindow           _scroll;
  private Overlay                  _overlay;
  private DBImage?                 _image;
  private Pixbuf?                  _pixbuf;
  private bool                     _pixbuf_changed;
  private Button                   _zoom_in;
  private Button                   _zoom_out;
  private Gee.HashMap<string,bool> _extensions;
  private double                   _scale = 1.0;
  private double                   _zoom_increment = 0.1;

  public bool editable { get; set; default = true; }
  public bool pixbuf_changed {
    get {
      return( _pixbuf_changed );
    }
  }

  public signal void image_added();

  /* Create the main window UI */
  public ImageArea( MainWindow win, Paned pane ) {

    Object( orientation: Orientation.VERTICAL, spacing: 0 );

    _win  = win;
    _pane = pane;

    add_image_area();

    /* Gather the list of available image extensions */
    get_image_extensions();

  }

  /* Creates the image area */
  private void add_image_area() {

    _scroll = new ScrolledWindow() {
      vscrollbar_policy = ALWAYS,
      hscrollbar_policy = ALWAYS
    };
    _scroll.scroll_child.connect((t,h) => {
      _win.reset_timer();
      return( false );
    });

    _zoom_in = new Button.from_icon_name( "list-add-symbolic" );
    _zoom_in.clicked.connect(() => {
      display_pixbuf( null, null, null, (_scale + _zoom_increment) );
    });

    _zoom_out = new Button.from_icon_name( "list-remove-symbolic" );
    _zoom_out.clicked.connect(() => {
      display_pixbuf( null, null, null, (_scale - _zoom_increment) );
    });

    var zbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign        = Align.CENTER,
      valign        = Align.END,
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };
    zbox.add_css_class( "zoom-padding" );
    zbox.add_css_class( Granite.STYLE_CLASS_BACKGROUND );
    zbox.append( _zoom_in );
    zbox.append( _zoom_out );

    var btn_revealer = new Revealer() {
      reveal_child    = false,
      transition_type = RevealerTransitionType.CROSSFADE,
      child           = zbox
    };

    var overlay_motion = new EventControllerMotion();
    _overlay = new Overlay() {
      child = _scroll
    };
    _overlay.add_controller( create_image_drop() );
    _overlay.add_controller( overlay_motion );
    _overlay.add_overlay( btn_revealer );

    overlay_motion.enter.connect((x, y) => {
      _win.reset_timer();
      btn_revealer.reveal_child = true;
      // _scroll.set_policy( PolicyType.ALWAYS, PolicyType.ALWAYS );
    });
    overlay_motion.leave.connect(() => {
      _win.reset_timer();
      btn_revealer.reveal_child = false;
      // _scroll.set_policy( PolicyType.NEVER, PolicyType.NEVER );
    });

    append( _overlay );

  }

  /* Gathers the supported image extensions that we can support */
  private void get_image_extensions() {

    _extensions = new Gee.HashMap<string,bool>();

    var formats = Pixbuf.get_formats();
    foreach( var format in formats ) {
      foreach( var ext in format.get_extensions() ) {
        _extensions.set( ext, true );
      }
    }

  }

  /* Returns true if the given URI is a supported image based on its extension */
  private bool is_uri_supported_image( string uri ) {
    string[] parts = uri.split( "." );
    return( _extensions.has_key( parts[parts.length - 1] ) );
  }

  /* Retrieves an image object used for saving to database */
  public void get_images( DBEntry entry ) {
    /*
    _pixbuf_changed = false;
    if( _pixbuf == null ) {
      return( null );
    } else {
      var image = new DBImage( _pixbuf, _pane.position, _scroll.vadjustment.value, _scroll.hadjustment.value, _scale );
      return( image );
    }
    */
  }

  /* Sets the image to the given object */
  public void set_images( DBEntry? entry ) {
    /*
    _image = image;
    if( _image == null ) {
      _pixbuf = null;
    } else {
      _pixbuf = _image.pixbuf;
      display_pixbuf( _image.pos, _image.vadj, _image.hadj, _image.scale );
    }
    */
  }

  /* Create the image drop handler */
  public DropTarget create_image_drop() {

    var drop = new Gtk.DropTarget( Type.STRING, DragAction.COPY );

    drop.motion.connect((x, y) => {
      return( editable ? DragAction.COPY : 0 );
    });

    drop.drop.connect((val, x, y) => {
      var uri = val.get_string().strip();
      if( (Uri.peek_scheme( uri ) != null) && is_uri_supported_image( uri ) ) {
        var from_file = File.new_for_uri( uri );
        try {
          GLib.FileIOStream stream;
          var to_file = File.new_tmp( "imgXXXXXX-%s".printf( from_file.get_basename() ), out stream );
          from_file.copy( to_file, FileCopyFlags.OVERWRITE );
          _pixbuf = new Pixbuf.from_file( to_file.get_path() );
          display_pixbuf( 200, 0.0, 0.0, 1.0 );
          to_file.delete();
          return( true );
        } catch( Error e ) {
          stdout.printf( "ERROR:  Unable to convert image file to pixbuf: %s\n", e.message );
        }
      }
      return( false );
    });

    return( drop );

  }

  /* Adds or changes the image associated with the current entry */
  public void add_image() {

    var dialog = Utils.make_file_chooser( _( "Select an image" ), _win, FileChooserAction.OPEN, _( "Add Image" ) );

    /* Add filters */
    var filter = new FileFilter() {
      name = _( "PNG Images" )
    };
    filter.add_suffix( "png" );
    dialog.add_filter( filter );

    dialog.response.connect((id) => {
      _win.reset_timer();
      if( id == ResponseType.ACCEPT ) {
        var file = dialog.get_file();
        if( file != null ) {
          try {
            set_pixbuf( new Pixbuf.from_file( file.get_path() ) );
            image_added();
          } catch( Error e ) {
            stdout.printf( "ERROR:  Unable to convert image file to pixbuf: %s\n", e.message );
          }
        }
      }
      dialog.close();
    });

    dialog.show();

  }

  /* Returns true if the image of the entry or its positioning information had changed since it was loaded */
  public bool changed() {
    return( _pixbuf_changed || (_pixbuf != null) );
  }

  /* Sets the internal pixbuf to the specified value and updates the display */
  private void set_pixbuf( Pixbuf? pixbuf ) {
    _pixbuf = pixbuf;
    _pixbuf_changed = true;
    display_pixbuf( 200, 0.0, 0.0, 1.0 );
  }

  /* Removes the image associated with the current entry */
  public void remove_image() {
    set_pixbuf( null );
  }

  /* Handles the proper display of the current pixbuf */
  private void display_pixbuf( int? pane_pos, double? vadj, double? hadj, double? scale ) {
    if( _pixbuf == null ) {
      _pane.start_child = null;
    } else {
      if( (scale != null) && (scale > 0.0) && (scale <= 2.0) ) {
        _scale = scale;
      }
      var buf = _pixbuf.scale_simple(
                  (int)(_pixbuf.get_width() * _scale),
                  (int)(_pixbuf.get_height() * _scale),
                  InterpType.BILINEAR
                );
      var img = new Picture.for_pixbuf( buf ) {
        halign     = Align.FILL,
        hexpand    = true,
        can_shrink = false
      };
      img.add_css_class( "text-background" );
      _scroll.child = img;
      _scroll.vadjustment.upper = (double)img.paintable.get_intrinsic_height();
      _scroll.hadjustment.upper = (double)img.paintable.get_intrinsic_width();
      if( vadj != null ) {
        _scroll.vadjustment.value = vadj;
      }
      if( hadj != null ) {
        _scroll.hadjustment.value = hadj;
      }
      _pane.start_child = this;
      if( pane_pos != null ) {
        _pane.position = pane_pos;
      }
    }
  }

}

