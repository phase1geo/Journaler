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

  private int thumbnail_height = 100;

  private MainWindow               _win;
  private Journal                  _journal;
  private Box                      _image_box;
  private Gee.HashMap<string,bool> _extensions;
  private Array<DBImage>           _images = new Array<DBImage>();

  public bool editable { get; set; default = true; }

  /* Create the main window UI */
  public ImageArea( MainWindow win ) {

    Object( orientation: Orientation.VERTICAL, spacing: 0 );

    _win = win;

    add_image_area();

    /* Gather the list of available image extensions */
    get_image_extensions();

    /* Set the size of this widget */
    set_size_request( -1, thumbnail_height );

  }

  /* Creates the image area */
  private void add_image_area() {

    _image_box = new Box( Orientation.HORIZONTAL, 5 );
    _image_box.add_css_class( "image-padding" );
    _image_box.add_css_class( "text-background" );
    _image_box.set_size_request( -1, thumbnail_height );

    var scroll = new ScrolledWindow() {
      hscrollbar_policy = AUTOMATIC,
      child             = _image_box
    };
    scroll.set_size_request( -1, (thumbnail_height + 10) );
    scroll.scroll_child.connect((t,h) => {
      _win.reset_timer();
      return( false );
    });

    append( scroll );

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
    for( int i=0; i<_images.length; i++ ) {
      entry.add_image( _images.index( i ) );
    }
  }

  /* Sets the image to the given object */
  public void set_images( Journal journal, DBEntry? entry ) {

    _journal = journal;

    hide();

    _images.remove_range( 0, _images.length );

    foreach( var image in entry.images ) {
      add_image( image );
    }

  }

  /* Adds the given image to the scrollable image box */
  private void add_image( DBImage image ) {

    var pixbuf = image.make_pixbuf( _journal, thumbnail_height );

    if( pixbuf != null ) {

      var gesture = new GestureClick();
      var img = new Picture.for_pixbuf( pixbuf ) {
        can_shrink = false,
        halign = Align.START,
        valign = Align.START,
        tooltip_text = image.description
      };
      img.add_controller( gesture );
      img.add_css_class( "text-background" );
      img.set_size_request( -1, thumbnail_height );

      gesture.pressed.connect((n_press, x, y) => {
        if( n_press == 2 ) {
          stdout.printf( "Display image\n" );
        }
      });

      /* Add the image picture to the scrollable box */
      _image_box.append( img );

      /* Add the image to the list */
      _images.append_val( image );

      /* Make sure that this widget is seen */
      show();

    }

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
        var image = new DBImage();
        image.store_file( _journal, uri );
        add_image( image );
      }
      return( false );
    });

    return( drop );

  }

  /* Adds or changes the image associated with the current entry */
  public void add_new_image() {

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
          var image  = new DBImage();
          var stored = image.store_file( _journal, file.get_uri() );
          stdout.printf( "stored: %s\n", stored.to_string() );
          add_image( image );
        }
      }
      dialog.close();
    });

    dialog.show();

  }

  /* Returns true if the image of the entry or its positioning information had changed since it was loaded */
  public bool changed() {
    // TBD
    return( false );
  }

  /* Removes the image associated with the current entry */
  public void remove_image() {
    // TBD
  }

}

