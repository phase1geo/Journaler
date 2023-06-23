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

public class TextArea : Box {

  private MainWindow       _win;
  private Journals         _journals;
  private Journal?         _journal = null;
  private DBEntry?         _entry = null;
  private Entry            _title;
  private Label            _date;
  private TagBox           _tags;
  private GtkSource.View   _text;
  private GtkSource.Buffer _buffer;
  private int              _font_size = 12;
  private int              _text_margin = 20;
  private string           _theme = "cobalt-light";
  private Revealer         _image_revealer;
  private Revealer         _burger_add_revealer;
  private Revealer         _burger_change_revealer;

  public int font_size {
    get {
      return( _font_size );
    }
    set {
      if( _font_size != value ) {
        _font_size = value;
        update_theme();
      }
    }
  }

  public string theme {
    get {
      return( _theme );
    }
    set {
      if( _theme != value ) {
        _theme = value;
        update_theme();
      }
    }
  }

  /* Create the main window UI */
  public TextArea( MainWindow win, Journals journals ) {

    Object( orientation: Orientation.VERTICAL, spacing: 0 );

    _win = win;
    _journals = journals;

    /* Add the UI components */
    add_text_area();

    /* Set the CSS for this widget */
    update_theme();

  }

  /* Creates the textbox with today's entry. */
  private void add_text_area() {

    var line_spacing = 5;

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

    var tbox = new Box( Orientation.HORIZONTAL, 5 );
    tbox.add_css_class( "title-box" );
    tbox.add_css_class( "text-background" );
    tbox.append( _title );
    tbox.append( create_burger_menu() );

    /* Add the date */
    _date = new Label( "" ) {
      halign = Align.FILL,
      xalign = (float)0
    };
    _date.add_css_class( "date" );
    _date.add_css_class( "text-background" );

    /* Add the tags */
    _tags = new TagBox();
    _tags.add_class( "date" );
    _tags.add_class( "text-background" );

    var sep = new Separator( Orientation.HORIZONTAL );

    _image_revealer = new Revealer() {
      reveal_child = false
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
      pixels_inside_wrap = line_spacing
    };
    _text.add_controller( text_focus );
    _text.add_css_class( "journal-text" );

    _title.activate.connect(() => {
      _text.grab_focus();
    });
    _title.changed.connect(() => {
      if( _title.text == "" ) {
        _title.remove_css_class( "title-bold" );
      } else {
        _title.add_css_class( "title-bold" );
      }
    });

    title_focus.leave.connect(() => {
      save();
    });

    /*
    text_focus.leave.connect(() => {
      save();
    });
    */

    var scroll_box = new Box( Orientation.VERTICAL, 0 );
    scroll_box.append( _image_revealer );
    scroll_box.append( _text );

    var scroll = new ScrolledWindow() {
      vscrollbar_policy = PolicyType.AUTOMATIC,
      child = scroll_box
    };

    append( tbox );
    append( _date );
    append( _tags );
    append( sep );
    append( scroll );

  }

  /* Creates burger menu and populates it with features */
  private MenuButton create_burger_menu() {

    /* Create the menubutton itself */
    var mb = new MenuButton() {
      icon_name = "view-more-symbolic",
      halign    = Align.END,
    };

    var add_image = new Button.with_label( _( "Add Image" ) );
    add_image.clicked.connect(() => {
      mb.popdown();
      add_entry_image();
    });

    var add_box = new Box( Orientation.VERTICAL, 0 );
    add_box.append( add_image );

    _burger_add_revealer = new Revealer() {
      reveal_child = true,
      child = add_box
    };

    var change_image = new Button.with_label( _( "Change Image" ) );
    change_image.clicked.connect(() => {
      mb.popdown();
      add_entry_image();
    });

    var remove_image = new Button.with_label( _( "Remove Image" ) );
    remove_image.clicked.connect(() => {
      mb.popdown();
      remove_entry_image();
    });

    var change_box = new Box( Orientation.VERTICAL, 0 );
    change_box.append( change_image );
    change_box.append( remove_image );

    _burger_change_revealer = new Revealer() {
      reveal_child = false,
      child = change_box
    };

    var menu_box = new Box( Orientation.VERTICAL, 0 );
    menu_box.append( _burger_add_revealer );
    menu_box.append( _burger_change_revealer );

    var burger_popover = new Popover() {
      has_arrow = false,
      child = menu_box
    };
    mb.popover = burger_popover;
    mb.add_css_class( "text-background" );

    return( mb );

  }

  /* Adds or changes the image associated with the current entry */
  private void add_entry_image() {

    var dialog = new FileChooserDialog( _( "Select an image" ), _win, FileChooserAction.OPEN,
                                        _( "Cancel" ), ResponseType.CANCEL,
                                        _( "Open" ), ResponseType.ACCEPT );

    /* Add filters */
    var filter = new FileFilter() {
      name = _( "PNG Images" )
    };
    filter.add_suffix( "png" );
    dialog.add_filter( filter );

    dialog.response.connect((id) => {
      if( id == ResponseType.ACCEPT ) {
        var file = dialog.get_file();
        if( file != null ) {
          try {
            var img = new Picture.for_file( file ) {
              // content_fit = ContentFit.CONTAIN
            };
            _image_revealer.child = img;
            _image_revealer.reveal_child = true;
            image_added();
          } catch( Error e ) {
            stderr.printf( "ERROR: %s\n", e.message );
          }
        }
      }
      dialog.close();
    });

    dialog.show();

  }

  /* Removes the image associated with the current entry */
  private void remove_entry_image() {

    stdout.printf( "Removing entry image\n" );

  }

  private void image_added() {
    _burger_add_revealer.reveal_child = false;
    _burger_change_revealer.reveal_child = true;
  }

  private void image_removed() {
    _burger_add_revealer.reveal_child = true;
    _burger_change_revealer.reveal_child = false;
  }

  /* Sets the theme and CSS classes */
  private void update_theme() {

    /* Update the text buffer theme */
    var style_mgr = GtkSource.StyleSchemeManager.get_default();
    var style = style_mgr.get_scheme( _theme );
    _buffer.style_scheme = style;

    /* Set the CSS */
    var provider = new CssProvider();
    var css_data = """
      .journal-text {
        font-size: %dpt;
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
      .text-background {
        background-color: %s;
      }
      .text-padding {
        padding: 0px %dpx;
      }
    """.printf( _font_size, _font_size, _text_margin, style.get_style( "background-pattern" ).background, (_text_margin - 4) );
    provider.load_from_data( css_data.data );
    StyleContext.add_provider_for_display( get_display(), provider, STYLE_PROVIDER_PRIORITY_APPLICATION );

  }

  /* Saves the contents of the text area as an entry in the current database */
  public void save() {

    /* If the text area is not editable or has not changed, there's no need to save */
    if( (_journal == null) || (_entry == null) || ((!_title.editable || (_title.text == _entry.title)) && (!_text.editable || !_text.buffer.get_modified()))) {
      return;
    }

    var entry = new DBEntry.with_date( _title.text, _text.buffer.text, null, _tags.entry.get_tag_list(), _entry.date );

    if( _journal.db.save_entry( entry ) ) {
      if( (_journals.current == _journal) && (_title.text != _entry.text) ) {
        _journals.current_changed( true );
      }
      stdout.printf( "Saved successfully to journal %s\n", _journal.name );
    }

  }

  /* Sets the entry contents to the given entry, saving the previous contents, if necessary */
  public void set_buffer( DBEntry entry, bool editable ) {

    if( _text.buffer.get_modified() ) {
      save();
    }

    _journal = _journals.current;
    _entry   = entry;

    /* Set the title */
    _title.text = entry.title;
    _title.editable = editable;

    /* Set the date */
    var dt = entry.datetime();
    _date.label = dt.format( "%A, %B %e, %Y" );

    /* Set the tags */
    _tags.journal = _journal;
    _tags.entry   = entry;
    _tags.update_tags();

    /* Set the buffer text to the entry text */
    _text.buffer.begin_irreversible_action();
    _text.buffer.text = entry.text;
    _text.buffer.end_irreversible_action();

    /* Set the editable bit */
    _text.editable = editable;

    /* Clear the modified bits */
    _text.buffer.set_modified( false );

    /* Set the grab */
    var title_empty = _title.text == "";
    var tags_empty  = _tags.entry.tags.length() == 0;
    var text_empty  = _text.buffer.text == "";
    if( title_empty && tags_empty && text_empty ) {
      _title.grab_focus();
    } else if( tags_empty && text_empty ) {
      _tags.grab_focus();
    } else {
      _text.grab_focus();
    }

  }

}

