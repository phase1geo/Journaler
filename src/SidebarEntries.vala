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

public class SidebarEntries : Box {

  private const int _sidebar_width = 300;

  private Journals       _journals;
  private Array<DBEntry> _listbox_entries;
  private MenuButton     _journal_mb;
  private ListBox        _journal_list;
  private ListBox        _listbox;
  private Calendar       _cal;
  private bool           _ignore_cal_select_day = false;

  public signal void edit_journal( Journal? journal );
  public signal void show_journal_entry( DBEntry entry, bool editable );

  /* Create the main window UI */
  public SidebarEntries( Journals journals ) {

    Object( orientation: Orientation.VERTICAL, spacing: 5, margin_start: 5, margin_end: 5, margin_top: 5, margin_bottom: 5 );

    _journals = journals;
    _journals.current_changed.connect(() => {
      populate();
    });
    _journals.list_changed.connect(() => {
      populate_journal_list();
    });
    _listbox_entries = new Array<DBEntry>();

    /* Add UI elements */
    add_journals();
    add_current_list();
    add_calendar();

  }

  /* Creates the current journal sidebar */
  private void add_journals() {

    var journal_popover = new Popover() {
      has_arrow = false
    };

    _journal_mb = new MenuButton() {
      halign  = Align.FILL,
      hexpand = true,
      popover = journal_popover
    };

    _journal_list = new ListBox();
    _journal_list.row_activated.connect((row) => {
      var index = row.get_index();
      _journals.set_current( index );
      journal_popover.popdown();
    });

    journal_popover.child = _journal_list;

    var add = new Button.from_icon_name( "list-add-symbolic" );
    add.clicked.connect(() => {
      edit_journal( null );
      tooltip_text = _( "Add new journal" );
    });

    var box = new Box( Orientation.HORIZONTAL, 5 );
    box.append( _journal_mb );
    box.append( add );

    append( box );

  }

  /* Adds the current listbox UI */
  private void add_current_list() {

    _listbox = new ListBox() {
      show_separators = true,
      activate_on_single_click = true
    };

    _listbox.row_selected.connect((row) => {
      if( row == null ) {
        return;
      }
      var index = row.get_index();
      var date  = _listbox_entries.index( index ).date;
      show_entry_for_date( date, false );
    });

    var lb_scroll = new ScrolledWindow() {
      hscrollbar_policy = PolicyType.NEVER,
      vscrollbar_policy = PolicyType.AUTOMATIC,
      halign            = Align.FILL,
      hexpand           = true,
      hexpand_set       = true,
      vexpand           = true,
      child             = _listbox
    };

    append( lb_scroll );

  }

  /* Adds the calendar UI */
  private void add_calendar() {

    var today = new DateTime.now_local();

    _cal = new Calendar() {
      show_heading = true,
      year         = today.get_year(),
      month        = today.get_month() - 1
    };

    _cal.day_selected.connect(() => {
      if( _ignore_cal_select_day ) {
        return;
      }
      var dt = _cal.get_date();
      var date = DBEntry.datetime_date( dt );
      var index = get_listbox_index_for_date( date );
      if( index != -1 ) {
        _listbox.select_row( _listbox.get_row_at_index( index ) );
      } else {
        _listbox.select_row( null );
        show_entry_for_date( date, false );
      }
    });

    _cal.next_month.connect( populate_calendar );
    _cal.next_year.connect(  populate_calendar );
    _cal.prev_month.connect( populate_calendar );
    _cal.prev_year.connect(  populate_calendar );

    append( _cal );

  }

  /* Populates the list of journal entries in the menubutton dropdown list */
  public void populate_journal_list() {

    /* Clear the box */
    var row = _journal_list.get_row_at_index( 0 );
    while( row != null ) {
      _journal_list.remove( row );
      row = _journal_list.get_row_at_index( 0 );
    }

    for( int i=0; i<_journals.num_journals(); i++ ) {

      var journal = _journals.get_journal( i );

      var lbl = new Label( journal.name ) {
        halign  = Align.FILL,
        hexpand = true,
        xalign  = (float)0
      };

      var edit = new Button.from_icon_name( "edit-symbolic" ) {
        halign = Align.END
      };

      edit.clicked.connect(() => {
        edit_journal( journal );
      });

      var box = new Box( Orientation.HORIZONTAL, 5 ) {
        margin_start = 5,
        margin_end = 5,
        margin_top = 5,
        margin_bottom = 5
      };

      box.append( lbl );
      box.append( edit );

      _journal_list.append( box );

    }

  }

  /* Populates the sidebar with information from the database */
  private void populate() {

    _journal_mb.label = _journals.current.name;

    if( _listbox_entries.length > 0 ) {
      _listbox_entries.remove_range( 0, _listbox_entries.length );
    }

    if( !_journals.current.db.get_all_entries( ref _listbox_entries ) ) {
      stdout.printf( "ERROR:  Unable to get all entries in the journal\n" );
      return;
    }

    populate_listbox();
    populate_calendar();

  }

  /* Populates the all entries listbox with date from the database */
  private void populate_listbox() {

    /* Clear the listbox */
    var row = _listbox.get_row_at_index( 0 );
    while( row != null ) {
      _listbox.remove( row );
      row = _listbox.get_row_at_index( 0 );
    }

    /* Populate the listbox */
    for( int i=0; i<_listbox_entries.length; i++ ) {
      var entry = _listbox_entries.index( i );
      var label = new Label( "<b>" + entry.gen_title() + "</b>" ) {
        halign     = Align.START,
        hexpand    = true,
        use_markup = true,
        ellipsize  = Pango.EllipsizeMode.END
      };
      label.add_css_class( "listbox-head" );
      var date = new Label( entry.date ) {
        halign  = Align.END,
        hexpand = true
      };
      var box = new Box( Orientation.VERTICAL, 0 ) {
        halign        = Align.FILL,
        hexpand       = true,
        width_request = 300,
        margin_top    = 5,
        margin_bottom = 5,
        margin_start  = 5,
        margin_end    = 5
      };
      box.append( label );
      box.append( date );
      _listbox.append( box );
    }

  }

  /* Populates the calendar with marks that match the current month/year */
  private void populate_calendar() {

    for( int i=0; i<_listbox_entries.length; i++ ) {
      var entry = _listbox_entries.index( i );
      var day   = entry.get_day();
      if( (entry.get_year() == _cal.year) && (entry.get_month() == (_cal.month + 1)) ) {
        _cal.mark_day( day );
      } else if( _cal.get_day_is_marked( day ) ) {
        _cal.unmark_day( day );
      }
    }

    /* Select the current date again to make sure that everything draw correctly */
    var current = _cal.get_date();
    _ignore_cal_select_day = true;
    _cal.select_day( _cal.get_date().add_days( 1 ) );
    _cal.select_day( current );
    _ignore_cal_select_day = false;

  }

  /* Retrieves the index of the listbox that contains the given date */
  private int get_listbox_index_for_date( string date ) {
    for( int i=0; i<_listbox_entries.length; i++ ) {
      if( _listbox_entries.index( i ).date == date ) {
        return( i );
      }
    }
    return( -1 );
  }

  /* Displays the entry for the given date */
  public void show_entry_for_date( string date, bool create_if_needed ) {

    var entry = new DBEntry();
    entry.date = date;

    /* Attempt to load the entry */
    var load_result = _journals.current.db.load_entry( ref entry, create_if_needed );

    /* If we created a new entry, update the list contents */
    if( load_result == DBLoadResult.CREATED ) {
      populate();
    }

    /* Make sure that the date is selected in the listbox */
    var index = get_listbox_index_for_date( entry.date );
    if( index != -1 ) {
      _listbox.select_row( _listbox.get_row_at_index( index ) );
      _ignore_cal_select_day = true;
      _cal.select_day( entry.datetime() );
      _ignore_cal_select_day = false;
    }

    /* Indicate that the entry should be displayed */
    show_journal_entry( entry, (load_result != DBLoadResult.FAILED) );

  }

}

