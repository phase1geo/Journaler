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

  private Journals _journals;
  private Journal  _journal;
  private Entry    _name;
  private TextView _description;
  private Revealer _del_revealer;
  private Button   _save;
  private string   _orig_name;
  private string   _orig_description;
  private bool     _save_name;
  private bool     _save_description;

  /* Indicates that the editing process hsa completed */
  public signal void done();

  /* Create the main window UI */
  public SidebarEditor( Journals journals ) {

    Object( orientation: Orientation.VERTICAL, spacing: 5, margin_start: 5, margin_end: 5, margin_top: 5, margin_bottom: 5 );

    _journals = journals;

    /* Add the UI elements */
    add_name();
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
      _save.sensitive = (name != "") && (_save_name || _save_description);
    });

    var box = new Box( Orientation.HORIZONTAL, 5 );
    box.append( lbl );
    box.append( _name );

    append( box );

  }

  /* Add the description elements */
  private void add_description() {

    /* Edit description */
    var lbl = new Label( Utils.make_title( _( "Description:" ) ) ) {
      halign     = Align.START,
      use_markup = true
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
      _save.sensitive   = (_name.buffer.text != "") && (_save_name || _save_description);
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
        var journal = new Journal( _name.buffer.text, _description.buffer.text );
        _journals.add_journal( journal );
      } else {
        _journal.name        = _name.buffer.text;
        _journal.description = _description.buffer.text;
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

  /* Sets up the journal editor panel and then switches to it */
  public void edit_journal( Journal? journal ) {

    _journal = journal;

    if( journal == null ) {
      _name.text = "";
      _description.buffer.text = "";
      _save.sensitive = false;
      _del_revealer.reveal_child = false;
    } else {
      _name.text = journal.name;
      _description.buffer.text = journal.description;
      _save.sensitive = true;
      _del_revealer.reveal_child = true;
    }

    _orig_name        = _name.text;
    _orig_description = _description.buffer.text;
    _save.sensitive   = false;
    _save_name        = false;
    _save_description = false;

  }

}

