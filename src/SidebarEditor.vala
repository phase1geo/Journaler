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

public class SidebarEditor : Box {

  private MainWindow _win;
  private Journals   _journals;
  private Templates  _templates;
  private Journal    _journal;
  private Entry      _name;
  private MenuButton _template;
  private ListBox    _template_list;
  private TextView   _description;
  private Revealer   _del_revealer;
  private Button     _save;
  private string     _orig_name;
  private string     _orig_template;
  private string     _orig_description;
  private bool       _save_name;
  private bool       _save_template;
  private bool       _save_description;

  /* Indicates that the editing process hsa completed */
  public signal void done();

  /* Create the main window UI */
  public SidebarEditor( MainWindow win, Journals journals, Templates templates ) {

    Object( orientation: Orientation.VERTICAL, spacing: 5, margin_start: 5, margin_end: 5, margin_top: 5, margin_bottom: 5 );

    _win       = win;
    _journals  = journals;
    _templates = templates;
    _templates.changed.connect((name, added) => {
      update_templates( name, added );
    });

    /* Add the UI elements */
    add_name();
    add_templates();
    add_description();
    add_button_bar();

  }

  /* Add the name elements */
  private void add_name() {

    var lbl = new Label( Utils.make_title( _( "Journal Name:" ) ) ) {
      use_markup = true
    };

    _name = new Entry() {
      halign  = Align.FILL,
      hexpand = true,
      placeholder_text = _( "Required" )
    };

    _name.changed.connect(() => {
      var name = _name.buffer.text;
      _save_name = (name != _orig_name) && (_journals.get_journal_by_name( name ) == null);
      _save.sensitive = (name != "") && (_save_name || _save_template || _save_description);
    });

    var box = new Box( Orientation.HORIZONTAL, 5 );
    box.append( lbl );
    box.append( _name );

    append( box );

  }

  /* Returns the name of the currently selected template */
  private string get_template_name() {
    return( (_template.label == _( "None" )) ? "" : _template.label );
  }

  /* Allows the user to choose a default template to use with the journal when a new entry is added */
  private void add_templates() {

    var lbl = new Label( Utils.make_title( _( "Use Template:" ) ) ) {
      use_markup = true
    };

    var popover = new Popover() {
      has_arrow = false
    };

    _template_list = new ListBox();
    _template_list.row_activated.connect((row) => {
      var index = row.get_index();
      if( index == (_templates.templates.length() + 1) ) {
        _win.edit_template();
      } else {
        _template.label = (index == 0) ? _( "None" ) : _templates.templates.nth_data( index - 1 ).name;
        _save_template  = (get_template_name() != _orig_template);
        _save.sensitive = (_name.buffer.text != "") && (_save_name || _save_template || _save_description);
      }
      popover.popdown();
    });

    popover.child = _template_list;

    _template = new MenuButton() {
      halign    = Align.FILL,
      hexpand   = true,
      label     = _( "None" ),
      popover   = popover,
      sensitive = false
    };

    var box = new Box( Orientation.HORIZONTAL, 5 );
    box.append( lbl );
    box.append( _template );

    append( box );

  }

  /* Add the description elements */
  private void add_description() {

    /* Edit description */
    var lbl = new Label( Utils.make_title( _( "Description:" ) ) ) {
      halign     = Align.START,
      use_markup = true,
      margin_top = 5
    };

    _description = new TextView() {
      halign    = Align.FILL,
      hexpand   = true,
      valign    = Align.FILL,
      vexpand   = true,
      wrap_mode = WrapMode.WORD
    };
    _description.buffer.changed.connect(() => {
      _save_description = (_description.buffer.text != _orig_description);
      _save.sensitive   = (_name.buffer.text != "") && (_save_name || _save_template || _save_description);
    });

    var box = new Box( Orientation.VERTICAL, 5 );
    box.append( lbl );
    box.append( _description );

    append( box );

  }

  /* Add the button bar elements */
  private void add_button_bar() {

    var del = new Button.with_label( _( "Delete" ) );

    del.clicked.connect(() => {
      _journals.remove_journal( _journal );
      done();
    });
    del.add_css_class( "destructive-action" );

    _del_revealer = new Revealer() {
      transition_duration = 0,
      child = del
    };

    var cancel = new Button.with_label( _( "Cancel" ) );

    cancel.clicked.connect(() => {
      done();
    });

    _save = new Button.with_label( _( "Save" ) ) {
      sensitive = false
    };
    _save.add_css_class( "suggested-action" );

    _save.clicked.connect(() => {
      if( _journal == null ) {
        var journal = new Journal( _name.buffer.text, get_template_name(), _description.buffer.text );
        _journals.add_journal( journal );
      } else {
        _journal.name        = _name.buffer.text;
        _journal.template    = get_template_name();
        _journal.description = _description.buffer.text;
        stdout.printf( "name: %s, template: %s\n", _journal.name, _journal.template );
        _journals.save();
      }
      done();
    });

    var rbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign = Align.END,
      hexpand = true,
    };
    rbox.append( cancel );
    rbox.append( _save );

    var box = new Box( Orientation.HORIZONTAL, 5 );
    box.append( _del_revealer );
    box.append( rbox );

    append( box );

  }

  /* Adds list label item */
  private void add_list_label( string name ) {

    var lbl = new Label( name ) {
      margin_top    = 5,
      margin_bottom = 5,
      margin_start  = 10,
      margin_end    = 10,
      halign        = Align.FILL,
      hexpand       = true,
      xalign        = (float)0
    };

    _template_list.append( lbl );

  }

  /* Updates the available templates in the template list */
  public void update_templates( string name, bool added ) {

    /* Clear the box */
    var row = _template_list.get_row_at_index( 0 );
    while( row != null ) {
      _template_list.remove( row );
      row = _template_list.get_row_at_index( 0 );
    }

    _template.sensitive = true;

    /* Add the list contents */
    add_list_label( _( "None" ) );
    foreach( var template in _templates.templates ) {
      add_list_label( template.name );
    }
    add_list_label( _( "Create new template" ) );

    /* If we just added a new template, we'll set the label */
    if( (name != "") && added ) {
      _template.label = name;
      _save.sensitive = (_name.text != "");
    }

  }

  /* Sets up the journal editor panel and then switches to it */
  public void edit_journal( Journal? journal ) {

    _journal = journal;

    if( journal == null ) {
      _name.text = "";
      _template.label = _( "None" );
      _description.buffer.text = "";
      _save.sensitive = false;
      _del_revealer.reveal_child = false;
    } else {
      _name.text = journal.name;
      _template.label = (journal.template == "") ? _( "None" ) : journal.template;
      _description.buffer.text = journal.description;
      _save.sensitive = true;
      _del_revealer.reveal_child = true;
    }

    _orig_name        = _name.text;
    _orig_template    = _template.label;
    _orig_description = _description.buffer.text;

    _save.sensitive   = false;
    _save_name        = false;
    _save_template    = false;
    _save_description = false;

  }

}

