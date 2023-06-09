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
  private Templates        _templates;
  private Journal?         _journal = null;
  private DBEntry?         _entry = null;
  private Entry            _title;
  private MenuButton       _burger;
  private Label            _date;
  private TagBox           _tags;
  private GtkSource.View   _text;
  private GtkSource.Buffer _buffer;
  private string           _theme;
  private Paned            _pane;
  private ScrolledWindow   _iscroll;
  private Pixbuf?          _pixbuf = null;
  private bool             _pixbuf_changed = false;
  private GLib.Menu        _image_menu;
  private GLib.Menu        _templates_menu;
  private Statistics       _stats;
  private Label            _quote;
  private Revealer         _quote_revealer;
  private Quotes           _quotes;

  private const GLib.ActionEntry action_entries[] = {
    { "action_add_entry_image",    action_add_entry_image },
    { "action_remove_entry_image", action_remove_entry_image },
    { "action_insert_template",    action_insert_template, "s" }
  };

  /* Create the main window UI */
  public TextArea( MainWindow win, Journals journals, Templates templates ) {

    Object( orientation: Orientation.VERTICAL, spacing: 0 );

    _win       = win;
    _journals  = journals;
    _templates = templates;

    /* Create the list of quotes to use */
    _quotes = new Quotes();

    /* Update the templates menu */
    _templates.changed.connect((name, added) => {
      _templates_menu.remove_all();
      foreach( var template in _templates.templates ) {
        _templates_menu.append( template.name, "textarea.action_insert_template('%s')".printf( template.name ) );
      }
    });

    /* Add the UI components */
    add_text_area();

    /* Set the CSS for this widget */
    win.themes.theme_changed.connect((name) => {
      _theme = name;
      update_theme();
    });
    Journaler.settings.changed.connect((key) => {
      switch( key ) {
        case "editor-font-size"    :  set_font_size();      break;
        case "editor-margin"       :  set_margin( false );  break;
        case "editor-line-spacing" :  set_line_spacing();   break;
        case "enable-quotations"   :  
          if( _buffer.text == "" ) {
            _quote_revealer.reveal_child = Journaler.settings.get_boolean( "enable-quotations" );
          }
          break;
      }
    });

    /* Add the menu actions */
    var actions = new SimpleActionGroup();
    actions.add_action_entries( action_entries, this );
    insert_action_group( "textarea", actions );

  }

  /* Sets the font size of the text widget */
  private void set_font_size() {

    update_theme();
    
  }

  /* Sets the margin around the text widget */
  private void set_margin( bool init ) {

    var margin = Journaler.settings.get_int( "editor-margin" );

    _text.top_margin    = margin / 2;
    _text.left_margin   = margin;
    _text.bottom_margin = margin;
    _text.right_margin  = margin;

    if( !init ) {
      update_theme();
    }

  }

  /* Sets the text line spacing */
  private void set_line_spacing() {

    var line_spacing = Journaler.settings.get_int( "editor-line-spacing" );

    _text.pixels_below_lines = line_spacing;
    _text.pixels_inside_wrap = line_spacing;

  }

  /* Returns the widget that should receive the grab focus when this pane is placed into view */
  public Widget get_focus_widget() {

    return( _title );

  }

  /* Creates the textbox with today's entry. */
  private void add_text_area() {

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

    /* Create the menubutton itself */
    _burger = new MenuButton() {
      icon_name  = "view-more-symbolic",
      halign     = Align.END,
      menu_model = create_burger_menu()
    };

    var tbox = new Box( Orientation.HORIZONTAL, 5 );
    tbox.add_css_class( "title-box" );
    tbox.add_css_class( "text-background" );
    tbox.append( _title );
    tbox.append( _burger );

    /* Add the date */
    _date = new Label( "" ) {
      halign = Align.FILL,
      xalign = (float)0
    };
    _date.add_css_class( "date" );
    _date.add_css_class( "text-background" );

    /* Add the tags */
    _tags = new TagBox( _win );
    _tags.add_class( "date" );
    _tags.add_class( "text-background" );

    var sep1 = new Separator( Orientation.HORIZONTAL );
    var sep2 = new Separator( Orientation.HORIZONTAL );

    /* Add the quote region */
    _quote = new Label( "" ) {
      halign    = Align.FILL,
      hexpand   = true,
      xalign    = (float)0,
      wrap      = true
    };
    _quote.add_css_class( "text-background" );
    _quote.add_css_class( "quote" );
    _quote_revealer = new Revealer() {
      reveal_child = false,
      child        = _quote
    };

    /* Now let's setup some stuff related to the text field */
    var lang_mgr = GtkSource.LanguageManager.get_default();
    var lang     = lang_mgr.get_language( "markdown" );

    /* Create the text entry view */
    _buffer = new GtkSource.Buffer.with_language( lang );
    _text = new GtkSource.View.with_buffer( _buffer ) {
      valign             = Align.FILL,
      vexpand            = true,
      wrap_mode          = WrapMode.WORD,
      cursor_visible     = true,
      enable_snippets    = true
    };
    _text.add_css_class( "journal-text" );
    _buffer.changed.connect(() => {
      _win.reset_timer();
      if( _quote_revealer.reveal_child && Journaler.settings.get_boolean( "dismiss-quotation-on-write" ) ) {
        _quote_revealer.transition_duration = 2000;
        _quote_revealer.reveal_child        = false;
      }
    });

    set_line_spacing();
    set_margin( true );

    _title.activate.connect(() => {
      _text.grab_focus();
    });
    _title.changed.connect(() => {
      _win.reset_timer();
      if( _title.text == "" ) {
        _title.remove_css_class( "title-bold" );
      } else {
        _title.add_css_class( "title-bold" );
      }
    });

    title_focus.leave.connect(() => {
      _title.select_region( 0, 0 );
      save();
    });

    var tscroll = new ScrolledWindow() {
      vscrollbar_policy = PolicyType.AUTOMATIC,
      child = _text
    };
    tscroll.scroll_child.connect((t,h) => {
      _win.reset_timer();
      return( false );
    });

    _pane = new Paned( Orientation.VERTICAL ) {
      end_child = tscroll
    };

    _iscroll = new ScrolledWindow() {
      vscrollbar_policy = AUTOMATIC,
      hscrollbar_policy = AUTOMATIC
    };
    _iscroll.scroll_child.connect((t,h) => {
      _win.reset_timer();
      return( false );
    });

    _stats = new Statistics( _text.buffer );

    append( tbox );
    append( _date );
    append( _tags );
    append( sep1 );
    append( _quote_revealer );
    append( _pane );
    append( sep2 );
    append( _stats );

  }

  /* Creates burger menu and populates it with features */
  private MenuModel create_burger_menu() {

    /* Create image menu */
    _image_menu = new GLib.Menu();
    _image_menu.append( _( "Add Image" ), "textarea.action_add_entry_image" );

    /* Create templates menu */
    _templates_menu = new GLib.Menu();

    var template_menu = new GLib.Menu();
    template_menu.append_submenu( _( "Insert Template" ), _templates_menu );

    var menu = new GLib.Menu();
    menu.append_section( null, _image_menu );
    menu.append_section( null, template_menu );

    return( menu );

  }

  /* Adds or changes the image associated with the current entry */
  private void action_add_entry_image() {

    _win.reset_timer();

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
            _pixbuf = new Pixbuf.from_file( file.get_path() );
            _pixbuf_changed = true;
            display_pixbuf( 200, 0.0, 0.0 );
            save();
          } catch( Error e ) {
            stdout.printf( "ERROR:  Unable to convert image file to pixbuf: %s\n", e.message );
          }
        }
      }
      dialog.close();
    });

    dialog.show();

  }

  /* Handles the proper display of the current pixbuf */
  private void display_pixbuf( int pane_pos, double vadj, double hadj ) {
    if( _pixbuf == null ) {
      _pane.start_child = null;
      image_removed();
    } else {
      var img = new Picture.for_pixbuf( _pixbuf ) {
        halign = Align.FILL,
        hexpand = true,
        can_shrink = false
      };
      img.add_css_class( "text-background" );
      _iscroll.child = img;
      _iscroll.vadjustment.upper = (double)img.paintable.get_intrinsic_height();
      _iscroll.hadjustment.upper = (double)img.paintable.get_intrinsic_width();
      _iscroll.vadjustment.value = vadj;
      _iscroll.hadjustment.value = hadj;
      _pane.start_child = _iscroll;
      _pane.position = pane_pos;
      image_added();
    }
  }

  /* Removes the image associated with the current entry */
  private void action_remove_entry_image() {
    _win.reset_timer();
    _pixbuf = null;
    _pixbuf_changed = true;
    display_pixbuf( 200, 0.0, 0.0 );
    save();
  }

  /* Inserts the given template text at the current insertion cursor location */
  private void action_insert_template( SimpleAction action, Variant? variant ) {
    _win.reset_timer();
    insert_template( variant.get_string() );
  }

  /* Inserts the given snippet name */
  private bool insert_template( string name ) {
    var snippet = _templates.get_snippet( name );
    if( snippet != null ) {
      TextIter iter;
      _buffer.get_iter_at_offset( out iter, _buffer.cursor_position );
      _text.push_snippet( snippet, ref iter );
      _text.grab_focus();
      return( true );
    }
    return( false );
  }

  /* Updates the UI when an image is added to the current entry */
  private void image_added() {
    _image_menu.remove_all();
    _image_menu.append( _( "Change Image" ), "textarea.action_add_entry_image" );
    _image_menu.append( _( "Remove Image" ), "textarea.action_remove_entry_image" );
  }

  /* Updates the UI when an image is removed from the current entry */
  private void image_removed() {
    _image_menu.remove_all();
    _image_menu.append( _( "Add Image" ), "textarea.action_add_entry_image" );
  }

  /* Sets the theme and CSS classes */
  private void update_theme() {

    /* Update the text buffer theme */
    var style_mgr = GtkSource.StyleSchemeManager.get_default();
    var style = style_mgr.get_scheme( _theme );
    _buffer.style_scheme = style;

    var font_size = Journaler.settings.get_int( "editor-font-size" );
    var margin    = Journaler.settings.get_int( "editor-margin" );

    /* Set the CSS */
    var provider = new CssProvider();
    var css_data = """
      .journal-text {
        font-size: %dpt;
        font-family: monospace;
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
      .quote {
        padding-left: %dpx;
        padding-right: 5px;
        padding-top: 5px;
        padding-bottom: 5px;
      }
      .text-background {
        background-color: %s;
      }
      .text-padding {
        padding: 0px %dpx;
      }
    """.printf( font_size, font_size, margin, margin, style.get_style( "background-pattern" ).background, (margin - 4) );
    provider.load_from_data( css_data.data );
    StyleContext.add_provider_for_display( get_display(), provider, STYLE_PROVIDER_PRIORITY_APPLICATION );

  }

  /* Returns true if the title of the entry has changed since it was loaded */
  private bool title_changed() {
    return( _title.editable && (_title.text != _entry.title) );
  }

  /* Returns true if the image of the entry or its positioning information had changed since it was loaded */
  private bool image_changed() {
    return( _pixbuf_changed ||
            ((_pixbuf != null) &&
             ((_pane.position != _entry.image_pos) ||
              (_iscroll.vadjustment.value != _entry.image_vadj) ||
              (_iscroll.hadjustment.value != _entry.image_hadj))) );
  }

  /* Returns true if the text of the entry has changed since it was loaded */
  private bool text_changed() {
    return( _text.editable && _text.buffer.get_modified() );
  }

  /* Saves the contents of the text area as an entry in the current database */
  public void save() {

    /* If the text area is not editable or has not changed, there's no need to save */
    if( (_journal == null) || (_entry == null) || (!title_changed() && !image_changed() && !text_changed()) ) {
      return;
    }

    var entry = new DBEntry.with_date( 
      _title.text, _text.buffer.text, _pixbuf, _pane.position,
      _iscroll.vadjustment.value, _iscroll.hadjustment.value,
      _pixbuf_changed, _tags.entry.get_tag_list(), _entry.date, _entry.time
    );

    if( _journal.db.save_entry( entry ) ) {
      if( (_journals.current == _journal) && (_title.text != _entry.text) ) {
        _journals.current_changed( true );
      }

      _entry = entry;
      _pixbuf_changed = false;

      /* Update the goals */
      _win.goals.mark_achievement( entry.date, false );
      if( _stats.word_goal_reached() ) {
        _win.goals.mark_achievement( entry.date, true );
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
    _title.text      = entry.title;
    _title.editable  = editable;
    _title.can_focus = editable;
    _title.focusable = editable;

    /* Set the date */
    var dt = entry.datetime();
    _date.label = dt.format( "%A, %B %e, %Y  %I:%M %p" );

    /* Set the image */
    _pixbuf = entry.image;
    _pixbuf_changed = false;
    display_pixbuf( entry.image_pos, entry.image_vadj, entry.image_hadj );

    /* Set the tags */
    _tags.journal = _journal;
    _tags.entry   = entry;
    _tags.update_tags();
    _tags.editable = editable;

    /* Show the quote of the day if the text field is empty */
    if( (entry.text == "") && Journaler.settings.get_boolean( "enable-quotations" ) && editable ) {
      _quote.label                        = _quotes.get_quote();
      _quote_revealer.transition_duration = 0;
      _quote_revealer.reveal_child        = true;
    } else {
      _quote_revealer.transition_duration = 0;
      _quote_revealer.reveal_child        = false;
    }

    /* Set the buffer text to the entry text or insert the snippet */
    _text.buffer.begin_irreversible_action();
    _text.buffer.text = "";
    if( (entry.text != "") || !insert_template( _journals.current.template ) ) {
      _text.buffer.text = entry.text;
    }
    _text.buffer.end_irreversible_action();

    /* Set the editable bit */
    _text.editable  = editable;
    _text.can_focus = editable;
    _text.focusable = editable;

    /* Clear the modified bits */
    _text.buffer.set_modified( false );

    /* Set the grab */
    if( editable ) {
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

    /* Handle other UI state related to the editable indicator */
    if( editable ) {
      _burger.show();
    } else {
      _burger.hide();
    }

  }

  /* Sets the reviewer mode */
  public void set_reviewer_mode( bool review_mode ) {
    set_buffer( _entry, !review_mode );
  }

}

