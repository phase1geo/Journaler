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

public class ImageArea : Box {

  private int thumbnail_height = 100;

  private MainWindow               _win;
  private Journal                  _journal;
  private Box                      _image_box;
  private Gee.HashMap<string,bool> _extensions;
  private Array<DBImage>           _images = new Array<DBImage>();

  private Button  _viewer_prev_btn;
  private Button  _viewer_next_btn;
  private Picture _viewer_preview;
  private Entry   _viewer_description;
  private DBImage _viewer_image;

  public bool editable { get; set; default = true; }
  public bool empty {
    get {
      return( _images.length == 0 );
    }
  }

  /* Create the main window UI */
  public ImageArea( MainWindow win ) {

    Object( orientation: Orientation.VERTICAL, spacing: 0 );

    _win = win;

    add_image_area();

    /* Gather the list of available image extensions */
    get_image_extensions();

    /* Set the size of this widget */
    set_size_request( -1, thumbnail_height );

    /* Make sure our background matches the color used by the text area */
    Idle.add(() => {
      add_css_class( "text-background" );
      return( false );
    });

  }

  /* Creates the image area */
  private void add_image_area() {

    _image_box = new Box( Orientation.HORIZONTAL, 5 );
    _image_box.add_controller( create_image_drop() );
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
  public bool is_uri_supported_image( string uri ) {
    string[] parts = uri.split( "." );
    return( _extensions.has_key( parts[parts.length - 1].down() ) );
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

    /* Clear the images array */
    _images.remove_range( 0, _images.length );

    /* Clear the image box */
    while( _image_box.get_first_child() != null ) {
      _image_box.remove( _image_box.get_first_child() );
    }

    /* Add in the images */
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

      var motion  = new EventControllerMotion();
      var overlay = new Overlay() {
        child = img
      };
      overlay.add_controller( motion );

      var del_btn = new Button.from_icon_name( "edit-delete-symbolic" );
      del_btn.clicked.connect(() => {
        _image_box.remove( overlay );
        if( image.state == ChangeState.NEW ) {
          for( int i=0; i<_images.length; i++ ) {
            if( _images.index( i ) == image ) {
              _images.remove_index( i );
              break;
            }
          }
        } else {
          image.state = ChangeState.DELETED;
        }
      });

      var dbox = new Box( Orientation.HORIZONTAL, 0 ) {
        halign = Align.END,
        valign = Align.START,
        margin_start  = 5,
        margin_end    = 5,
        margin_top    = 5,
        margin_bottom = 5
      };
      dbox.add_css_class( Granite.STYLE_CLASS_BACKGROUND );
      dbox.add_css_class( "image-button" );
      dbox.append( del_btn );
      dbox.hide();

      var area = this;

      motion.enter.connect((x, y) => {
        if( area.editable ) {
          dbox.show();
        }
      });
      motion.leave.connect(() => {
        if( area.editable ) {
          dbox.hide();
        }
      });

      overlay.add_overlay( dbox );

      var image_index = (int)_images.length;

      gesture.pressed.connect((n_press, x, y) => {
        if( (n_press == 2) && area.editable ) {
          show_full_image( image_index );
          _win.show_pane( "image-view" );
        }
      });

      /* Add the image picture to the scrollable box */
      _image_box.append( overlay );

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
      add_image_from_uri( val.get_string().strip() );
      return( false );
    });

    return( drop );

  }

  /* Adds an image for the given URI if it is unique */
  public void add_image_from_uri( string text ) {
    var uri = text;
    if( FileUtils.test( uri, FileTest.EXISTS ) && (Uri.peek_scheme( uri ) == null) ) {
      uri = "file://" + uri;
    }
    if( (Uri.peek_scheme( uri ) != null) && is_uri_supported_image( uri ) ) {
      for( int i=0; i<_images.length; i++ ) {
        if( _images.index( i ).uri == uri ) {
          return;
        }
      }
      var image = new DBImage();
      if( image.store_file( _journal, uri ) ) {
        add_image( image );
      }
    }
  }

  /* Adds or changes the image associated with the current entry */
  public void add_new_image() {

    var dialog = Utils.make_file_chooser( _( "Select an image" ), _win, FileChooserAction.OPEN, _( "Add Image" ) );

    /* Add filters */
    var filter = new FileFilter() {
      name = _( "Image Files" )
    };
    filter.add_pixbuf_formats();
    dialog.add_filter( filter );

    dialog.response.connect((id) => {
      _win.reset_timer();
      if( id == ResponseType.ACCEPT ) {
        var file = dialog.get_file();
        if( file != null ) {
          add_image_from_uri( file.get_uri() );
        }
      }
      dialog.destroy();
    });

    dialog.show();

  }

  /* Returns true if the image of the entry or its positioning information had changed since it was loaded */
  public bool changed() {
    for( int i=0; i<_images.length; i++ ) {
      if( _images.index( i ).state != ChangeState.NONE ) {
        return( true );
      }
    }
    return( false );
  }

  /* Returns the index of the image to display */
  private int get_image_index( DBImage image ) {
    for( int i=0; i<_images.length; i++ ) {
      if( _images.index( i ).matches( image ) ) {
        return( i );
      }
    }
    return( -1 );
  }

  /* Updates the state of the current image */
  private void update_current_state() {
    if( _viewer_image.description != _viewer_description.text ) {
      _viewer_image.description = _viewer_description.text;
      if( _viewer_image.state == ChangeState.NONE ) {
        _viewer_image.state = ChangeState.CHANGED;
      }
    }
  }

  /* Create the full image viewer window */
  public Box create_full_image_viewer() {

    /* Create image carousel */
    _viewer_prev_btn = new Button.from_icon_name( "go-previous-symbolic" ) {
      valign    = Align.FILL,
      vexpand   = true,
      sensitive = false
    };
    _viewer_prev_btn.clicked.connect(() => {
      var index = get_image_index( _viewer_image );
      update_current_state();
      show_full_image( index - 1 );
    });

    _viewer_preview = new Picture() {
      halign  = Align.CENTER,
      hexpand = true,
      valign  = Align.START
    };

    _viewer_next_btn = new Button.from_icon_name( "go-next-symbolic" ) {
      valign    = Align.FILL,
      vexpand   = true,
      sensitive = false
    };
    _viewer_next_btn.clicked.connect(() => {
      var index = get_image_index( _viewer_image );
      update_current_state();
      show_full_image( index + 1 );
    });

    _viewer_description = new Entry() {
      placeholder_text = _( "Enter Description (Optional)" ),
      margin_start     = 5,
      margin_end       = 5,
      margin_bottom    = 20
    };

    var grid = new Grid() {
      halign  = Align.FILL,
      hexpand = true
    };

    grid.attach( _viewer_prev_btn, 0, 0 );
    grid.attach( _viewer_preview,  1, 0 );
    grid.attach( _viewer_next_btn, 2, 0 );
    grid.attach( _viewer_description, 1, 1 );

    var close_btn = new Button.with_label( _( "Close" ) ) {
      halign = Align.END,
      hexpand = true
    };
    close_btn.clicked.connect(() => {
      update_current_state();
      _win.show_pane( "entry-view" );
    });

    var bbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign = Align.FILL,
      hexpand = true
    };
    bbox.append( close_btn );

    var box = new Box( Orientation.VERTICAL, 5 ) {
      halign  = Align.FILL,
      valign  = Align.FILL,
      hexpand = true,
      vexpand = true,
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };
    box.append( grid );
    box.append( bbox );

    return( box );

  }

  /* Displays the image and description */
  public void show_full_image( int index ) {

    /* Get the index of the image to display */
    var image = _images.index( index );

    /* Handle the button sensitivity */
    _viewer_prev_btn.sensitive = (index > 0);
    _viewer_next_btn.sensitive = (index < (_images.length - 1));

    /* Display the button */
    _viewer_preview.set_pixbuf( image.make_pixbuf( _journal, 600 ) );

    /* Set the description field */
    _viewer_description.text = image.description;

    /* Save the current viewer image */
    _viewer_image = image;

  }

  /* Returns the widget will which receive input focus */
  public Widget get_focus_widget() {
    return( _viewer_description );
  }

}

