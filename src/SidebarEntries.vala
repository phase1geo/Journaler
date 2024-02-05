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

public class SidebarEntries : Box {

  private const int _sidebar_width = 300;

  private MainWindow     _win;
  private Journals       _journals;
  private Templates      _templates;
  private Array<DBEntry> _listbox_entries;
  private MenuButton     _journal_mb;
  private GLib.Menu      _journals_menu;
  private GLib.Menu      _hidden_menu;
  private ListBox        _listbox;
  private ScrolledWindow _lb_scroll;
  private Label          _lb_status;
  private Calendar       _cal;
  private Label          _cal_status;
  private Label          _streak;
  private bool           _ignore_select = false;
  private MenuButton     _burger_mb;
  private GLib.Menu      _journal_burger_menu;
  private GLib.Menu      _hidden_burger_menu;
  private GLib.Menu      _trash_burger_menu;
  private string         _selected_journal = "";
  private string         _selected_date    = "";
  private string         _selected_time    = "";
  private bool           _last_editable    = false;
  private bool           _show_hidden      = false;

  private const GLib.ActionEntry action_entries[] = {
    { "action_select_trash",         action_select_trash },
    { "action_select_journal",       action_select_journal, "s" },
    { "action_new_journal",          action_new_journal },
    { "action_edit_current_journal", action_edit_current_journal },
    { "action_show_hidden_journals", action_show_hidden_journals },
    { "action_empty_trash",          action_empty_trash }
  };

  public signal void edit_journal( Journal? journal );
  public signal void show_journal_entry( DBEntry entry, bool editable, SelectedEntryPos pos );

  public bool last_editable {
    set {
      _last_editable = value;
    }
  }

  /* Create the main window UI */
  public SidebarEntries( MainWindow win, TextArea text_area, Journals journals, Templates templates ) {

    Object( orientation: Orientation.VERTICAL, spacing: 5, margin_top: 5, margin_bottom: 5 );

    _win       = win;
    _templates = templates;

    _journals = journals;
    _journals.current_changed.connect((refresh) => {
      if( refresh ) {
        populate( get_selected_entry() );
      } else {
        populate( null );
        if( _journals.current != null ) {
          if( _journals.current.is_trash ) {
            _burger_mb.menu_model = _trash_burger_menu;
            action_set_enabled( "entries.action_empty_trash", (_listbox_entries.length > 0) );
            if( _listbox_entries.length > 0 ) {
              var listbox_entry = _listbox_entries.index( 0 );
              show_entry_for_date( listbox_entry.journal, listbox_entry.date, listbox_entry.time, false, true, SelectedEntryPos.OTHER, "constructor A" );
            } else {
              show_entry_for_date( _journals.current.name, "", "", false, false, SelectedEntryPos.OTHER, "constructor B" );
            }
          } else {
            _burger_mb.menu_model = _journal_burger_menu;
            show_entry_for_date( _journals.current.name, DBEntry.todays_date(), "", true, true, SelectedEntryPos.OTHER, "constructor C" );
          }
        }
      }
    });
    _journals.list_changed.connect(() => {
      populate_journal_menu();
    });

    text_area.entry_moved.connect((entry) => {
      populate( entry );
      if( _journals.current.is_trash ) {
        _burger_mb.menu_model = _trash_burger_menu;
        action_set_enabled( "entries.action_empty_trash", (_listbox_entries.length > 0) );
      } else {
        _burger_mb.menu_model = _journal_burger_menu;
      }
      if( entry.journal != _journals.current.name ) {
        if( _listbox_entries.length > 0 ) {
          var listbox_entry = _listbox_entries.index( 0 );
          show_entry_for_date( listbox_entry.journal, listbox_entry.date, listbox_entry.time, false, true, SelectedEntryPos.OTHER, "constructor F" );
        } else {
          show_entry_for_date( _journals.current.name, "", "", false, false, SelectedEntryPos.OTHER, "constructor G" );
        }
      }
    });

    _listbox_entries = new Array<DBEntry>();

    /* Add UI elements */
    add_journals();
    add_current_list();
    add_calendar();
    add_status();

    /* Add the menu actions */
    var actions = new SimpleActionGroup();
    actions.add_action_entries( action_entries, this );
    insert_action_group( "entries", actions );

    string[] keys = {"entry-title-prefix", "entry-title-suffix"};
    foreach( var key in keys ) {
      Journaler.settings.changed[key].connect(() => {
        var selected = _listbox.get_selected_row();
        if( selected != null ) {
          var entry = _listbox_entries.index( selected.get_index() );
          populate_listbox( entry );
        } else {
          populate_listbox( null );
        }
      });
    }

  }

  /* Creates the current journal sidebar */
  private void add_journals() {

    _journals_menu = new GLib.Menu();
    _hidden_menu   = new GLib.Menu();

    var trash_menu = new GLib.Menu();
    trash_menu.append( _journals.trash.name, "entries.action_select_trash" );

    var journal_menu = new GLib.Menu();
    journal_menu.append_section( null, _journals_menu );
    journal_menu.append_section( null, trash_menu );

    _journal_mb = new MenuButton() {
      halign     = Align.FILL,
      hexpand    = true,
      menu_model = journal_menu
    };

    var edit_menu = new GLib.Menu();
    edit_menu.append( _( "Edit current journal" ), "entries.action_edit_current_journal" );

    _hidden_burger_menu = new GLib.Menu();
    populate_hidden_burger_menu();

    _journal_burger_menu = new GLib.Menu();
    _journal_burger_menu.append( _( "Create New Journal" ), "entries.action_new_journal" );
    _journal_burger_menu.append_section( null, edit_menu );
    _journal_burger_menu.append_section( null, _hidden_burger_menu );

    _trash_burger_menu = new GLib.Menu();
    _trash_burger_menu.append( _( "Create New Journal" ), "entries.action_new_journal" );
    _trash_burger_menu.append( _( "Empty trash" ), "entries.action_empty_trash" );
    _trash_burger_menu.append_section( null, _hidden_burger_menu );

    _burger_mb = new MenuButton() {
      icon_name  = "view-more-symbolic",
      menu_model = _journal_burger_menu
    };

    var box = new Box( Orientation.HORIZONTAL, 5 ) {
      margin_start = 5,
      margin_end = 5
    };
    box.append( _journal_mb );
    box.append( _burger_mb );

    append( box );

  }

  /* Updates the items in the hidden burger menu to match the current "hidden" state */
  private void populate_hidden_burger_menu() {

    _hidden_burger_menu.remove_all();

    if( _show_hidden ) {
      _hidden_burger_menu.append( _( "Hide hidden journals" ), "entries.action_show_hidden_journals" );
    } else {
      _hidden_burger_menu.append( _( "Show hidden journals" ), "entries.action_show_hidden_journals" );
    }

  }

  /* Called when the user wishes to display the trash */
  private void action_select_trash() {
    _win.reset_timer();
    _journals.current = _journals.trash;
  }

  /* Called when a journal is selected in the dropdown menu */
  private void action_select_journal( SimpleAction action, Variant? variant ) {
    _win.reset_timer();
    _journals.current = _journals.get_journal_by_name( variant.get_string() );
  }

  /* Called when a new journal needs to be created on behalf of the user */
  private void action_new_journal() {
    _win.reset_timer();
    edit_journal( null );
  }

  /* Edits the current journal */
  private void action_edit_current_journal() {
    _win.reset_timer();
    edit_journal( _journals.current );
  }

  /* Displays the hidden journals */
  private void action_show_hidden_journals() {
    _win.reset_timer();
    _show_hidden = !_show_hidden;
    populate_hidden_burger_menu();
    populate_journal_menu();
  }

  /* Empties the trash */
  private void action_empty_trash() {

    _win.reset_timer();

    var dialog = new MessageDialog( _win, DialogFlags.MODAL, MessageType.WARNING, ButtonsType.OK_CANCEL, _( "Empty Trash?" ) ) {
      secondary_text = _( "All entries will be permanently deleted.\nThis operation cannot be undone." )
    };

    dialog.response.connect((response_id) => {
      if( response_id == ResponseType.ACCEPT ) {
        _journals.empty_trash();
      }
      dialog.close();
    });

    dialog.show();

  }

  /* Adds the current listbox UI */
  private void add_current_list() {

    _listbox = new ListBox() {
      show_separators = true,
      activate_on_single_click = true
    };

    _listbox.row_selected.connect((row) => {
      _win.reset_timer();
      if( _ignore_select || (row == null) ) {
        return;
      }
      var index   = row.get_index();
      var journal = _listbox_entries.index( index ).journal;
      var date    = _listbox_entries.index( index ).date;
      var time    = _listbox_entries.index( index ).time;
      show_entry_for_date( journal, date, time, false, true, SelectedEntryPos.OTHER, "add_current_list" );
    });

    _lb_scroll = new ScrolledWindow() {
      hscrollbar_policy = PolicyType.NEVER,
      vscrollbar_policy = PolicyType.AUTOMATIC,
      halign            = Align.FILL,
      hexpand           = true,
      hexpand_set       = true,
      vexpand           = true,
      child             = _listbox,
      margin_start      = 5,
      margin_end        = 5
    };
    _lb_scroll.scroll_child.connect((t,h) => {
      _win.reset_timer();
      return( true );
    });

    var sep = new Separator( Orientation.HORIZONTAL ) {
      hexpand = true
    };

    append( _lb_scroll );
    append( sep );

  }

  /* Adds the calendar UI */
  private void add_calendar() {

    var today = new DateTime.now_local();

    _cal = new Calendar() {
      show_heading = true,
      year         = today.get_year(),
      month        = today.get_month() - 1,
      margin_start = 5,
      margin_end   = 5
    };

    _cal.day_selected.connect(() => {
      if( _ignore_select ) {
        return;
      }
      _win.reset_timer();
      var dt = _cal.get_date();
      var date = DBEntry.datetime_date( dt );
      var index = get_listbox_index_for_date_time( date, "" );
      if( index != -1 ) {
        _listbox.select_row( _listbox.get_row_at_index( index ) );
        Utils.scroll_to_selected_row( _listbox );
      } else {
        _listbox.select_row( null );
        show_entry_for_date( _journals.current.name, date, "", (strcmp( date, DBEntry.todays_date() ) < 1), true, SelectedEntryPos.OTHER, "add_calendar" );
      }
    });

    _cal.next_month.connect(() => {
      _win.reset_timer();
      populate_calendar();
    });
    _cal.next_year.connect(() => {
      _win.reset_timer();
      populate_calendar();
    });
    _cal.prev_month.connect(() => {
      _win.reset_timer();
      populate_calendar();
    });
    _cal.prev_year.connect(() => {
      _win.reset_timer();
      populate_calendar();
    });

    var sep = new Separator( Orientation.HORIZONTAL ) {
      hexpand = true
    };

    append( _cal );
    append( sep );

    _win.themes.theme_changed.connect((name) => {
      _cal.remove_css_class( _win.themes.dark_mode ? "calendar-light" : "calendar-dark" );
      _cal.add_css_class( _win.themes.dark_mode ? "calendar-dark" : "calendar-light" );
    });

  }

  /* Display the journal status information */
  private void add_status() {

    var journal = new Label( Utils.make_title( _( "Journal:" ) ) ) {
      use_markup = true
    };

    _lb_status = new Label( "" );

    var jbox = new Box( Orientation.HORIZONTAL, 5 );
    jbox.append( journal );
    jbox.append( _lb_status );

    var calendar = new Label( Utils.make_title( _( "Monthly:" ) ) ) {
      use_markup = true
    };

    _cal_status = new Label( "" );

    var cbox = new Box( Orientation.HORIZONTAL, 5 );
    cbox.append( calendar );
    cbox.append( _cal_status );

    var streak = new Label( Utils.make_title( _( "Current Streak:" ) ) ) {
      use_markup = true
    };

    _streak = new Label( "" );

    var sbox = new Box( Orientation.HORIZONTAL, 5 );
    sbox.append( streak );
    sbox.append( _streak );

    var box = new Box( Orientation.HORIZONTAL, 10 ) {
      halign = Align.CENTER,
      margin_start = 5,
      margin_end = 5
    };
    box.append( jbox );
    box.append( cbox );
    box.append( sbox );

    append( box );

  }

  /* Populates the list of journal entries in the menubutton dropdown list */
  public void populate_journal_menu() {

    _journals_menu.remove_all();
    _hidden_menu.remove_all();

    for( int i=0; i<_journals.num_journals(); i++ ) {
      var journal = _journals.get_journal( i );
      if( !journal.hidden ) {
        _journals_menu.append( journal.name, "entries.action_select_journal('%s')".printf( journal.name ) );
      }
    }

    if( _show_hidden ) {
      for( int i=0; i<_journals.num_journals(); i++ ) {
        var journal = _journals.get_journal( i );
        if( journal.hidden ) {
          _hidden_menu.append( journal.name, "entries.action_select_journal('%s')".printf( journal.name ) );
        }
      }
      _journals_menu.append_submenu( _( "Hidden Journals" ), _hidden_menu );
    }

  }

  /* Returns the currently selected entry in the listbox (if one can be found); otherwise, returns null */
  private DBEntry? get_selected_entry() {

    if( _listbox_entries.length > 0 ) {
      var selected = _listbox.get_selected_row();
      if( selected != null ) {
        return( _listbox_entries.index( selected.get_index() ) );
      }
    }

    return( null );

  }

  /* Populates the sidebar with information from the database */
  private void populate( DBEntry? select_entry ) {

    _journal_mb.label = (_journals.current == null) ? _( "No journal selected" ) : _journals.current.name;

    if( _listbox_entries.length > 0 ) {
      _listbox_entries.remove_range( 0, _listbox_entries.length );
    }

    if( _journals.current != null ) {
      if( !_journals.current.db.get_all_entries( _journals.current.is_trash, _listbox_entries ) ) {
        stderr.printf( "ERROR:  Unable to get all entries in the journal\n" );
        return;
      }
    }

    populate_listbox( select_entry );
    populate_calendar();

  }

  /* Populates the all entries listbox with date from the database */
  private void populate_listbox( DBEntry? select_entry ) {

    var vpos = _lb_scroll.vadjustment.get_value();

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
      var date = new Label( entry.date + ", " + entry.time ) {
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
      if( _journals.current.is_trash ) {
        var journal = new Label( entry.journal ) {
          halign  = Align.START,
          hexpand = true
        };
        var lbox = new Box( Orientation.HORIZONTAL, 0 );
        lbox.append( journal );
        lbox.append( date );
        box.append( lbox );
      } else {
        box.append( date );
      }
      _listbox.append( box );
    }

    _lb_status.label = _listbox_entries.length.to_string();
    _streak.label    = calculate_current_streak();

    if( select_entry != null ) {
      var index = get_listbox_index_for_date_time( select_entry.date, select_entry.time );
      if( index != -1 ) {
        _ignore_select = true;
        _listbox.select_row( _listbox.get_row_at_index( index ) );
        _ignore_select = false;
      }
      _lb_scroll.vadjustment.set_value( vpos );
    }

  }

  /* Calculates the current entry streak for the current journal */
  private string calculate_current_streak() {

    var last   = DBEntry.todays_date();
    var streak = 0;

    for( int i=0; i<_listbox_entries.length; i++ ) {
      var entry = _listbox_entries.index( i );
      if( entry.date == last ) {
        streak++;
      } else {
        var edate = entry.datetime().add_days( 1 );
        if( DBEntry.datetime_date( edate ) == last ) {
          streak++;
        } else {
          break;
        }
      }
      last = entry.date;
    }

    return( streak.to_string() );

  }

  /* Populates the calendar with marks that match the current month/year */
  private void populate_calendar() {

    var count = 0;

    /* Clear all of the marked days */
    _cal.clear_marks();

    for( int i=0; i<_listbox_entries.length; i++ ) {
      var entry = _listbox_entries.index( i );
      var day   = entry.get_day();
      if( (entry.get_year() == _cal.year) && (entry.get_month() == (_cal.month + 1)) ) {
        _cal.mark_day( day );
        count++;
      }
    }

    _cal_status.label = count.to_string();

    /* Select the current date again to make sure that everything draw correctly */
    var current = _cal.get_date();
    _ignore_select = true;
    _cal.select_day( _cal.get_date().add_days( 1 ) );
    _cal.select_day( current );
    _ignore_select = false;

  }

  /* Retrieves the index of the listbox that contains the given date */
  private int get_listbox_index_for_date_time( string date, string time ) {
    for( int i=0; i<_listbox_entries.length; i++ ) {
      if( (_listbox_entries.index( i ).date == date) && ((time == "") || (_listbox_entries.index( i ).time == time)) ) {
        return( i );
      }
    }
    return( -1 );
  }

  /*
   Selects the given entry in the listbox without changing the entry in the textbox.  This
   is useful for updating UI state only.
  */
  private void select_entry_only( DBEntry entry ) {
    var index = get_listbox_index_for_date_time( entry.date, entry.time );
    if( index != -1 ) {
      stdout.printf( "In select_entry_only, index: %d\n", index );
      _ignore_select = true;
      _listbox.select_row( _listbox.get_row_at_index( index ) );
      _cal.select_day( entry.datetime() );
      Utils.scroll_to_selected_row( _listbox );
      _ignore_select = false;
    }
  }

  /* Displays the entry for the given date */
  public void show_entry_for_date( string journal_name, string date, string time, bool create_if_needed, bool editable, SelectedEntryPos pos, string msg ) {

    if( (_selected_journal == journal_name) && (_selected_date == date) && (_selected_time == time) && (_last_editable == editable) ) {
      return;
    }

    _selected_journal = journal_name;
    _selected_date    = date;
    _selected_time    = time;
    _last_editable    = editable;

    var is_trash  = _journals.current.is_trash;
    var entry     = new DBEntry();
    entry.journal = journal_name;
    entry.date    = date;
    entry.time    = time;
    
    /* Allow the TextArea to save before we purge */
    _win.text_area.save();

    /* Purge the empty entries but not today */
    var purged = _journals.current.db.purge_empty_entries( false );

    /* Attempt to load the entry */
    var load_result = _journals.current.db.load_entry( entry, (!is_trash && create_if_needed) );

    /* If we created a new entry, update the list contents */
    if( purged || (load_result == DBLoadResult.CREATED) ) {
      populate( entry );
    }

    /* Make sure that the date is selected in the listbox */
    select_entry_only( entry );

    /* Indicate that the entry should be displayed */
    show_journal_entry( entry, editable, pos );

  }

}

