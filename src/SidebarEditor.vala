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
  private Menu       _template_menu;
  private TextView   _description;
  private Revealer   _del_revealer;
  private Button     _save;
  private string     _orig_name;
  private string     _orig_template;
  private string     _orig_description;
  private bool       _save_name;
  private bool       _save_template;
  private bool       _save_description;

  private const GLib.ActionEntry action_entries[] = {
    { "action_set_template", action_set_template, "s" },
    { "action_new_template", action_new_template },
  };

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

    /* Add the menu actions */
    var actions = new SimpleActionGroup();
    actions.add_action_entries( action_entries, this );
    insert_action_group( "editor", actions );

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
      _win.reset_timer();
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

    _template_menu = new GLib.Menu();

    _template = new MenuButton() {
      halign     = Align.FILL,
      hexpand    = true,
      label      = _( "None" ),
      menu_model = _template_menu
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
      _win.reset_timer();
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
      _win.reset_timer();
      done();
    });
    del.add_css_class( "destructive-action" );

    _del_revealer = new Revealer() {
      transition_duration = 0,
      child = del
    };

    var cancel = new Button.with_label( _( "Cancel" ) );

    cancel.clicked.connect(() => {
      _win.reset_timer();
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
      _win.reset_timer();
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

  /* Updates the available templates in the template list */
  public void update_templates( string name, bool added ) {

    _template_menu.remove_all();

    var none_menu = new GLib.Menu();
    none_menu.append( _( "None" ), "editor.action_set_template('None')" );

    var list_menu = new GLib.Menu();
    foreach( var template in _templates.templates ) {
      list_menu.append( template.name, "editor.action_set_template('%s')".printf( template.name ) );
    }

    var new_menu = new GLib.Menu();
    new_menu.append( _( "Create New Template" ), "editor.action_new_template" );

    _template_menu.append_section( null, none_menu );
    _template_menu.append_section( null, list_menu );
    _template_menu.append_section( null, new_menu );

    /* If we just added a new template, we'll set the label */
    if( (name != "") && added ) {
      _template.label = name;
      _save.sensitive = (_name.text != "");
    }

  }

  /* Sets the template to the given value and updates the UI */
  private void action_set_template( SimpleAction action, Variant? variant ) {
    _win.reset_timer();
    _template.label = variant.get_string();
    _save_template  = (get_template_name() != _orig_template);
    _save.sensitive = (_name.buffer.text != "") && (_save_name || _save_template || _save_description);
  }

  /* Creates a new template */
  private void action_new_template() {
    _win.reset_timer();
    _win.edit_template();
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

