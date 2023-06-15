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

  private Journals         _journals;
  private DBEntry          _entry;
  private Entry            _title;
  private Label            _date;
  private GtkSource.View   _text;
  private GtkSource.Buffer _buffer;
  private int              _font_size = 12;
  private int              _text_margin = 20;
  private string           _theme = "cobalt-light";

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

  public signal void title_changed( string title, string date );

  /* Create the main window UI */
  public TextArea( Journals journals ) {

    Object( orientation: Orientation.VERTICAL, spacing: 0 );

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
      placeholder_text        = _( "Title (Optional)" ),
      has_frame               = false,
      enable_emoji_completion = true
    };
    _title.add_controller( title_focus );
    _title.add_css_class( "title" );
    _title.add_css_class( "text-background" );
    _title.add_css_class( "text-padding" );

    /* Add the date */
    _date = new Label( "" ) {
      halign = Align.FILL,
      xalign = (float)0
    };
    _date.add_css_class( "date" );
    _date.add_css_class( "text-background" );

    var sep = new Separator( Orientation.HORIZONTAL );

    /* Now let's setup some stuff related to the text field */
    var lang_mgr = GtkSource.LanguageManager.get_default();
    var lang     = lang_mgr.get_language( "markdown" );

    /* Create the text entry view */
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
    _text.add_css_class( "journal-text" );

    _title.activate.connect(() => {
      _text.grab_focus();
    });

    title_focus.leave.connect(() => {
      title_changed( _title.text, _entry.date );
    });

    var scroll = new ScrolledWindow() {
      vscrollbar_policy = PolicyType.AUTOMATIC,
      child = _text
    };

    append( _title );
    append( _date );
    append( sep );
    append( scroll );

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
      .date {
        padding-left: %dpx;
        padding-bottom: 5px;
      }
      .text-background {
        background-color: %s;
      }
      .text-padding {
        padding-left: %dpx;
        padding-right: %dpx;
        padding-top: %dpx;
        padding-bottom: %dpx;
      }
    """.printf( _font_size, _font_size, _text_margin, style.get_style( "background-pattern" ).background, (_text_margin - 4), (_text_margin - 4), 0, 0 );
    provider.load_from_data( css_data.data );
    StyleContext.add_provider_for_display( get_display(), provider, STYLE_PROVIDER_PRIORITY_APPLICATION );

  }

  /* Saves the contents of the text area as an entry in the current database */
  public void save() {

    /* If the text area is not editable or has not changed, there's no need to save */
    if( !_title.editable && (_title.text == _entry.text) && !_text.editable && !_text.buffer.get_modified()) {
      return;
    }

    var entry = new DBEntry.for_save( _title.text, _text.buffer.text );

    if( _journals.current.db.save_entry( entry ) ) {
      stdout.printf( "Saved successfully!\n" );
    } else {
      stdout.printf( "Save did not occur\n" );
    }

  }

  /* Sets the entry contents to the given entry, saving the previous contents, if necessary */
  public void set_buffer( DBEntry entry, bool editable ) {

    if( _text.buffer.get_modified() ) {
      save();
    }

    _entry = entry;

    /* Set the title */
    _title.text = entry.title;
    _title.editable = editable;

    /* Set the date */
    var dt = entry.datetime();
    _date.label = dt.format( "%A, %B %e, %Y" );

    /* Set the buffer text to the entry text */
    _text.buffer.begin_irreversible_action();
    _text.buffer.text = entry.text;
    _text.buffer.end_irreversible_action();

    /* Set the editable bit */
    _text.editable = editable;

    /* Clear the modified bits */
    _text.buffer.set_modified( false );

  }

}

