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
using Granite;

public enum SelectedEntryPos {
  FIRST,
  LAST,
  OTHER;

  public static SelectedEntryPos parse( int entries, int selected ) {
    if( selected == 0 ) {
      return( FIRST );
    } else if( selected == (entries - 1) ) {
      return( LAST );
    } else {
      return( OTHER );
    }
  }

  public bool prev_sensitivity() {
    return( this != FIRST );
  }

  public bool next_sensitivity() {
    return( this != LAST );
  }

}

public class Reviewer : Grid {

  private MainWindow _win;
  private Journals   _journals;

  private SavedReviews _reviews;

  private MenuButton  _journal_mb;
  private ListBox     _journal_lb;
  private Button      _journal_set_all;
  private Button      _journal_clear_all;
  private int         _num_journals = 0;
  private CheckButton _trash_cb;

  private MenuButton _tag_mb;
  private ListBox    _tag_lb;
  private Button     _tag_set_all;
  private Button     _tag_clear_all;
  private int        _num_tags = 0;
  private bool       _ignore_toggled = false;

  private DateSelector _start_date;
  private DateSelector _end_date;

  private SearchEntry _search_entry;
  private MenuButton  _search_save;
  private GLib.Menu   _saved_search_menu;
  private GLib.Menu   _saved_delete_menu;

  private ListBox                _match_lb;
  private ScrolledWindow         _lb_scroll;
  private Gee.ArrayList<DBEntry> _match_entries;
  private int                    _match_index;
  private Button                 _trash_btn;
  private Button                 _restore_btn;

  private const GLib.ActionEntry action_entries[] = {
    { "action_show_all",      action_show_all },
    { "action_save_review",   action_save_review,   "s" },
    { "action_load_review",   action_load_review,   "i" },
    { "action_delete_review", action_delete_review, "i" },
  };

  public signal void show_matched_entry( DBEntry entry, SelectedEntryPos pos );
  public signal void close_requested();

  /* Default constructor */
  public Reviewer( MainWindow win, Journals journals ) {

    Object( row_spacing: 5, column_spacing: 5, margin_start: 5, margin_end: 5, margin_top: 5, margin_bottom: 5 );

    _win           = win;
    _journals      = journals;
    _match_entries = new Gee.ArrayList<DBEntry>();
    _reviews       = new SavedReviews();

    /* Add the UI components */
    add_journal_list();
    add_tag_list();
    add_date_selector();
    add_close();
    add_search();
    add_search_save();

    /* Load the stored reviews */
    _reviews.load();
    populate_reviews();

    /* When the journals are loaded, grab the start date and use it in the start date widget */
    _journals.loaded.connect(() => {
      _start_date.default_date = _journals.get_start_date();
      _start_date.date         = _journals.get_start_date();
    });

    /* Add the menu actions */
    var actions = new SimpleActionGroup();
    actions.add_action_entries( action_entries, this );
    insert_action_group( "review", actions );

  }

  /* Creates the journal selection UI */
  private void add_journal_list() {

    var label = new Label( Utils.make_title( _( "Journals:" ) ) ) {
      use_markup = true
    };

    _journal_lb = new ListBox();

    _journal_set_all = new Button.with_label( _( "Select All" ) ) {
      halign  = Align.START,
      hexpand = true
    };
    _journal_set_all.clicked.connect(() => {
      _win.reset_timer();
      change_select_of_all_items( _journal_lb, true );
    });

    _journal_clear_all = new Button.with_label( _( "Clear All" ) ) {
      halign  = Align.END,
      hexpand = true
    };
    _journal_clear_all.clicked.connect(() => {
      _win.reset_timer();
      change_select_of_all_items( _journal_lb, false );
    });

    var bbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign  = Align.FILL,
      hexpand = true
    };
    bbox.append( _journal_set_all );
    bbox.append( _journal_clear_all );

    var sep = new Separator( Orientation.HORIZONTAL );

    var lbox = new Box( Orientation.VERTICAL, 5 ) {
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };
    lbox.append( bbox );
    lbox.append( _journal_lb );
    lbox.append( sep );

    var lbox_revealer = new Revealer() {
      reveal_child = true,
      child = lbox
    };

    _trash_cb = new CheckButton.with_label( _journals.trash.name ) {
      active        = false,
      margin_start  = 10,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 10 
    };
    _trash_cb.toggled.connect(() => {
      _win.reset_timer();
      lbox_revealer.reveal_child = !_trash_cb.active;
      do_search();
    });

    var tlbox = new Box( Orientation.VERTICAL, 0 );
    tlbox.append( lbox_revealer );
    tlbox.append( _trash_cb );

    var popover = new Popover() {
      has_arrow = false,
      child     = tlbox
    };

    _journal_mb = new MenuButton() {
      halign  = Align.START,
      popover = popover
    };

    var jbox = new Box( Orientation.HORIZONTAL, 5 );
    jbox.append( label );
    jbox.append( _journal_mb );

    attach( jbox, 0, 0 );

  }

  /* Creates the tag selection UI */
  private void add_tag_list() {

    var label = new Label( Utils.make_title( _( "Tags:" ) ) ) {
      use_markup = true
    };

    _tag_lb = new ListBox();

    _tag_set_all = new Button.with_label( _( "Select All" ) ) {
      halign  = Align.START,
      hexpand = true
    };
    _tag_set_all.clicked.connect(() => {
      _win.reset_timer();
      change_select_of_all_items( _tag_lb, true );
    });

    _tag_clear_all = new Button.with_label( _( "Clear All" ) ) {
      halign  = Align.END,
      hexpand = true
    };
    _tag_clear_all.clicked.connect(() => {
      _win.reset_timer();
      change_select_of_all_items( _tag_lb, false );
    });

    var bbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign  = Align.FILL,
      hexpand = true
    };
    bbox.append( _tag_set_all );
    bbox.append( _tag_clear_all );

    var lbox = new Box( Orientation.VERTICAL, 5 ) {
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };
    lbox.append( bbox );
    lbox.append( _tag_lb );

    var popover = new Popover() {
      has_arrow = false,
      child     = lbox
    };

    _tag_mb = new MenuButton() {
      halign  = Align.START,
      popover = popover
    };

    var tbox = new Box( Orientation.HORIZONTAL, 5 );
    tbox.append( label );
    tbox.append( _tag_mb );

    attach( tbox, 1, 0 );

  }

  /* Add the date selection UI */
  private void add_date_selector() {

    var range = new Label( Utils.make_title( _( "Date Range:" ) ) ) {
      use_markup = true
    };

    _start_date = new DateSelector();
    _start_date.changed.connect(() => {
      do_search();
    });

    var to = new Label( Utils.make_title( "-" ) ) {
      use_markup = true
    };

    _end_date = new DateSelector();
    _end_date.changed.connect(() => {
      do_search();
    });

    var dbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign  = Align.END,
      hexpand = true
    };
    dbox.append( range );
    dbox.append( _start_date );
    dbox.append( to );
    dbox.append( _end_date );

    attach( dbox, 2, 0 );

  }

  /* Adds a close button */
  private void add_close() {

    var close_btn = new Button.from_icon_name( "window-close-symbolic" );
    close_btn.clicked.connect(() => {
      close_requested();
    });

    attach( close_btn, 3, 0 );

  }

  /* Add the search UI */
  private void add_search() {

    _search_entry = new SearchEntry() {
      halign  = Align.FILL,
      hexpand = true,
      placeholder_text = _( "Search entry title and text" )
    };
    _search_entry.search_changed.connect(() => {
      do_search();
    });

    attach( _search_entry, 0, 1, 3 );

  }

  /* Add the saved search UI */
  private void add_search_save() {

    _saved_search_menu = new GLib.Menu();
    _saved_delete_menu = new GLib.Menu();

    var new_submenu = new GLib.Menu();
    new_submenu.append( _( "Save exact dates" ),                  "review.action_save_review(\"abs_abs\")" );
    new_submenu.append( _( "Save relative to exact start date" ), "review.action_save_review(\"abs_rel\")" );
    new_submenu.append( _( "Save relative to current date" ),     "review.action_save_review(\"rel_rel\")" );

    var new_entry = new GLib.Menu();
    new_entry.append_submenu( _( "Save search" ), new_submenu );

    var del_entry = new GLib.Menu();
    del_entry.append_submenu( _( "Delete saved search" ), _saved_delete_menu );

    var menu = new GLib.Menu();
    menu.append( _( "Show all entries" ), "review.action_show_all" );
    menu.append_section( null, _saved_search_menu );
    menu.append_section( null, new_entry );
    menu.append_section( null, del_entry );

    _search_save = new MenuButton() {
      icon_name  = "folder-symbolic",
      menu_model = menu
    };

    attach( _search_save, 3, 1 );

  }

  /* Populates the list of saved searches/reviews */
  private void populate_reviews() {

    _saved_search_menu.remove_all();
    _saved_delete_menu.remove_all();

    for( int i=0; i<_reviews.size(); i++ ) {
      var review = _reviews.get_review( i );
      _saved_search_menu.append( review.name, "review.action_load_review(%d)".printf( i ) );
      _saved_delete_menu.append( review.name, "review.action_delete_review(%d)".printf( i ) );
    }

  }

  /* Shows all entries */
  private void action_show_all() {
    initialize( null );
  }

  /* Handles search saves */
  private void action_save_review( SimpleAction action, Variant? variant ) {

    var search_type = variant.get_string();
    var start_abs   = false;
    var end_abs     = false;

    switch( search_type ) {
      case "abs_abs" :  start_abs = true;   end_abs = true;   break;
      case "abs_rel" :  start_abs = true;   end_abs = false;  break;
      case "rel_rel" :  start_abs = false;  end_abs = false;  break;
      default        :  assert_not_reached();
    }

    var journals = new List<string>();
    var tags     = new List<string>();

    /* Get the selected journals and tags */
    if( _trash_cb.active ) {
      journals.append( _journals.trash.name );
    } else {
      get_activated_items_from_list( _journal_lb, ref journals );
    }
    get_activated_items_from_list( _tag_lb, ref tags );

    /* Create the review and add it to the list */
    var review = new SavedReview( journals, _num_journals, tags, _num_tags, _start_date.date, start_abs, _end_date.date, end_abs, _search_entry.text );
    _reviews.add_review( review );

    /* Update the saved reviews */
    populate_reviews();

  }

  /* Loads the current review and performs the search */
  private void action_load_review( SimpleAction action, Variant? variant ) {

    var index  = variant.get_int32();
    var review = _reviews.get_review( index );

    initialize( review );

  }

  /* Deletes the selected review and updates the menu */
  private void action_delete_review( SimpleAction action, Variant? variant ) {

    var index = variant.get_int32();

    /* Remove the review */
    _reviews.remove_review( index );

    /* Update the saved reviews */
    populate_reviews();

  }

  /* Adds the given label as a checkbutton to the list */
  private void add_item_to_list( ListBox lb, string label, bool active ) {

    var btn = new CheckButton.with_label( label ) {
      active        = active,
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };
    btn.toggled.connect(() => {
      if( !_ignore_toggled ) {
        _win.reset_timer();
        do_search();
      }
    });

    lb.append( btn );

  }

  /* Gathers the list of all activated items from the given list */
  private void get_activated_items_from_list( ListBox lb, ref List<string> items ) {

    var i   = 0;
    var row = lb.get_row_at_index( i++ );

    while( row != null ) {
      CheckButton? cb = null;
      if( (row.child as CheckButton) == null ) {
        cb = (CheckButton)row.child.get_last_child();
      } else {
        cb = (CheckButton)row.child;
      }
      if( cb.active ) {
        items.append( cb.label );
      }
      row = lb.get_row_at_index( i++ );
    }

  }

  /* Selects all of the items in the list and perform a search, if necessary */
  private void change_select_of_all_items( ListBox lb, bool select ) {

    var i          = 0;
    var row        = lb.get_row_at_index( i++ );
    var run_search = false;

    _ignore_toggled = true;

    while( row != null ) {
      var cb = (CheckButton)row.child;
      if( cb.active != select ) {
        cb.active  = select;
        run_search = true;
      }
      row = lb.get_row_at_index( i++ );
    }

    _ignore_toggled = false;

    if( run_search ) {
      do_search();
    }

  }

  /* Clears the contents of the passed listbox */
  private void clear_listbox( ListBox lb ) {
    var row = lb.get_row_at_index( 0 );
    while( row != null ) {
      lb.remove( row );
      row = lb.get_row_at_index( 0 );
    }
  }

  /* Returns the string date for the given picker */
  private string get_date( DateSelector selector ) {
    return( DBEntry.datetime_date( selector.date ) );
  }

  /* Populates the journal listbox with the available journals to review */
  private void populate_journals( SavedReview? review = null ) {

    clear_listbox( _journal_lb );

    /* Get the list of available journal names and sort them */
    var journals = new List<string>();
    for( int i=0; i<_journals.num_journals(); i++ ) {
      if( !_journals.get_journal( i ).hidden ) {
        journals.append( _journals.get_journal( i ).name );
      }
    }

    var selected = new List<string>();
    if( (review == null) || review.all_journals ) {
      foreach( var journal in journals ) {
        selected.append( journal );
      }
    } else {
      foreach( var journal in review.journals ) {
        if( journals.find( journal ).length() > 0 ) {
          selected.append( journal );
        }
      }
    }

    selected.sort( strcmp );

    foreach( var journal_name in selected ) {
      add_item_to_list( _journal_lb, journal_name, true );
    }

    _num_journals = (int)journals.length();

  }

  /* Grab the lastest tags */
  private void populate_tags( SavedReview? review = null ) {

    clear_listbox( _tag_lb );

    /* Get the list of unique tags and sort them */
    var all_tags = new List<string>();
    for( int i=0; i<_journals.num_journals(); i++ ) {
      var journal = _journals.get_journal( i );
      if( !journal.hidden ) {
        var journal_tags = new Array<string>();
        if( journal.db.get_all_tags( journal_tags ) ) {
          for( int j=0; j<journal_tags.length; j++ ) {
            var tag = journal_tags.index( j );
            if( all_tags.find( tag ) == null ) {
              all_tags.append( tag );
            }
          }
        }
      }
    }

    var selected = new List<string>();
    if( (review == null) || review.all_journals ) {
      foreach( var tag in all_tags ) {
        selected.append( tag );
      }
    } else {
      foreach( var tag in review.tags ) {
        if( all_tags.find( tag ).length() > 0 ) {
          selected.append( tag );
        }
      }
    }
    selected.sort( strcmp );

    /* Populate the listbox */
    add_item_to_list( _tag_lb, _( "Untagged" ), true );
    foreach( var tag in selected ) {
      add_item_to_list( _tag_lb, tag, true );
    }

    _num_tags = (int)all_tags.length();

  }

  /* Initializes the dates in the range selectors */
  private void populate_dates( SavedReview? review = null ) {

    if( review == null ) {
      _start_date.set_to_default();
      _end_date.set_to_default();
    } else {
      _start_date.date = review.get_start_date();
      _end_date.date   = review.get_end_date();
    }

  }

  /* Initializes the reviewer UI when this is shown */
  public void initialize( SavedReview? review = null ) {

    /* Populate the journals and tags lists */
    populate_journals( review );
    populate_tags( review );
    populate_dates( review );

    _search_entry.text = (review == null) ? "" : review.search_str;

    /* Do an initial search */
    do_search();

  }

  /* This should be called prior to exiting the review mode. */
  public void on_close() {

    // TBD - We may not need this at this point

  }

  // --------------------------------------------------------------

  /* Creates the label that will be displayed on the journals or tags menubutton based on what is currently selected */
  public static string make_menubutton_label( List<string> list, int max_length, string all_str, string none_str ) {
    if( list.length() == 0 ) {
      return( none_str );
    } else if( list.length() == max_length ) {
      return( all_str );
    } else {
      string[] values = {};
      int      index  = 0;
      switch( list.length() ) {
        case 1  :  return( list.nth_data( 0 ) );
        case 2  :
        case 3  :
          foreach( var item in list ) {
            values += item;
          }
          return( string.joinv( ",", values ) );
        default :
          foreach( var item in list ) {
            if( index++ < 3 ) {
              values += item;
            }
          }
          return( "%s + %d more".printf( string.joinv( ", ", values ), ((int)list.length() - 3) ) );
      }
    }
  }

  /* Updates the state of the UI */
  private void update_ui_state( List<string> journals, List<string> tags ) {

    /* Update journal and tag listboxes */
    _journal_set_all.sensitive   = (journals.length() < _num_journals);
    _journal_clear_all.sensitive = (journals.length() > 0);
    _journal_mb.label = make_menubutton_label( journals, _num_journals, _( "All Journals" ), _( "No Journals" ) );

    _tag_set_all.sensitive   = (tags.length() < (_num_tags + 1));
    _tag_clear_all.sensitive = (tags.length() > 0);
    _tag_mb.label = make_menubutton_label( tags, _num_tags, _( "All Tags" ), _( "No Tags" ) );

  }

  /* Performs search of selected items, date ranges, and search terms */
  private void do_search() {

    var journals = new List<string>();
    var tags     = new List<string>();

    /* Get the selected journals and tags */
    if( _trash_cb.active ) {
      journals.append( _journals.trash.name );
    } else {
      get_activated_items_from_list( _journal_lb, ref journals );
    }
    get_activated_items_from_list( _tag_lb, ref tags );

    var start_date = get_date( _start_date );
    var end_date   = get_date( _end_date );

    /* Update the state of the UI */
    update_ui_state( journals, tags );

    /* Clear the list of match entries */
    clear_listbox( _match_lb );
    _match_entries.clear();

    /* Add the matching entries to the list */
    foreach( var journal_name in journals ) {
      var journal = (journal_name == _journals.trash.name) ? _journals.trash : _journals.get_journal_by_name( journal_name );
      journal.db.query_entries( (journal_name == _journals.trash.name), tags, start_date, end_date, _search_entry.text.strip(), _match_entries );
    }

    /* Sort the entries */
    _match_entries.sort((a, b) => {
      var date_match = strcmp( b.date, a.date );
      if( date_match == 0 ) {
        return( strcmp( a.journal, b.journal ) );
      }
      return( date_match );
    });

    /* Add the entries */
    _match_entries.foreach((journal_entry) => {
      add_match_entry( journal_entry );
      return( true );
    });

    /* Set the sensitivity of the action buttons */
    _trash_btn.sensitive   = false;
    _restore_btn.sensitive = false;

    /* Display the first entry */
    if( _match_entries.size > 0 ) {
      _match_lb.select_row( _match_lb.get_row_at_index( 0 ) );
    }

  }

  // --------------------------------------------------------------

  /* Displays the previous entry in the list */
  public void show_previous_entry() {
    var index = _match_index;
    _match_lb.selection_mode = SelectionMode.SINGLE;
    _match_lb.select_row( _match_lb.get_row_at_index( index - 1 ) );
  }

  /* Displays the next entry in the list */
  public void show_next_entry() {
    var index = _match_index;
    _match_lb.selection_mode = SelectionMode.SINGLE;
    _match_lb.select_row( _match_lb.get_row_at_index( index + 1 ) );
  }

  /* Displays the given entry in the textarea */
  private void show_entry( ListBoxRow? row ) {

    if( row == null ) return;

    _match_index = row.get_index();

    var entry    = _match_entries.get( _match_index );
    var selected = _match_lb.get_selected_rows().length();
    if( selected == 1 ) {
      show_matched_entry( entry, SelectedEntryPos.parse( _match_entries.size, _match_index ) );
      _match_lb.grab_focus();
      _trash_btn.sensitive   = false;
      _restore_btn.sensitive = false;
      show_row( row );
    }

    if( entry.trash ) {
      _restore_btn.sensitive = true;
    } else {
      _trash_btn.sensitive = true;
    }

    _match_lb.selection_mode = SelectionMode.MULTIPLE;

  }

  /* Makes sure that the specified row is within view in the viewport */
  private void show_row( ListBoxRow row ) {

    /* Adjust the lb_scroll viewport so that that current selected row is in view */
    double wleft, wtop, wbottom;
    row.translate_coordinates( _match_lb, 0, 0, out wleft, out wtop );
    wbottom = wtop + row.get_allocated_height();

    var top    = _lb_scroll.vadjustment.value;
    var bottom = top + _lb_scroll.vadjustment.page_size;

    Idle.add(() => {
      if( wtop < top ) {
        _lb_scroll.vadjustment.value = wtop;
      } else if( wbottom > bottom ) {
        _lb_scroll.vadjustment.value = wbottom - _lb_scroll.vadjustment.page_size;
      } else {
        _lb_scroll.vadjustment.value = top;
      }
      return( false );
    });

  }

  /* Creates the sidebar where matched entries will be displayed */
  public Box create_reviewer_match_sidebar() {

    _match_lb = new ListBox() {
      show_separators = true,
      activate_on_single_click = false,
      selection_mode  = SelectionMode.MULTIPLE,
      can_focus       = true
    };

    _match_lb.row_selected.connect((row) => {
      _win.reset_timer();
      show_entry( row );
    });

    _lb_scroll = new ScrolledWindow() {
      hscrollbar_policy = PolicyType.NEVER,
      vscrollbar_policy = PolicyType.AUTOMATIC,
      halign            = Align.FILL,
      hexpand           = true,
      hexpand_set       = true,
      vexpand           = true,
      child             = _match_lb
    };
    _lb_scroll.scroll_child.connect((t,h) => {
      _win.reset_timer();
      return( false );
    });

    _restore_btn = new Button.with_label( _( "Restore" ) );
    _restore_btn.clicked.connect( restore_from_trash );

    _trash_btn = new Button.with_label( _( "Move To Trash" ) );
    _trash_btn.clicked.connect( move_to_trash );

    var bbox = new Box( Orientation.HORIZONTAL, 5 ) {
      homogeneous = true,
      halign      = Align.FILL,
      hexpand     = true,
      valign      = Align.END
    };
    bbox.append( _trash_btn );
    bbox.append( _restore_btn );

    var box = new Box( Orientation.VERTICAL, 5 ) {
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };
    box.append( _lb_scroll );
    box.append( bbox );

    return( box );

  }

  /* Moves all entries to the trash */
  private void move_to_trash() {
    _win.reset_timer();
    foreach( var row in _match_lb.get_selected_rows() ) {
      var index   = row.get_index();
      var entry   = _match_entries.get( index );
      var journal = _journals.get_journal_by_name( entry.journal );
      if( !entry.trash ) {
        journal.move_entry( entry, _journals.trash );
      }
    }
    do_search();
  }

  /* Restores the entries from the trash */
  private void restore_from_trash() {
    _win.reset_timer();
    foreach( var row in _match_lb.get_selected_rows() ) {
      var index   = row.get_index();
      var entry   = _match_entries.get( index );
      var journal = _journals.get_journal_by_name( entry.journal );
      if( entry.trash ) {
        _journals.trash.move_entry( entry, journal );
      }
    }
    do_search();
  }

  /* Retrieves a portion of the matched entry text if the search entry contains any non-whitespace characters */
  private string get_matched_text( DBEntry entry ) {

    var text          = entry.text.replace( "\n", " " );
    var text_to_match = _search_entry.text.strip();
    var index         = text.index_of( text_to_match );

    if( (index == -1) || (text_to_match == "") ) {
      return( "" );
    } else {
      index = text.char_count( index );
    }

    var pre_chars     = 20;
    var post_chars    = 60;
    var start         = index - pre_chars;
    var end           = index + text_to_match.char_count();

    if( start < 0 ) {
      pre_chars = index;
      start     = 0;
    }
    if( (end + post_chars) > text.char_count() ) {
      post_chars = text.char_count() - end;
    }

    var pre_text   = text.substring( text.index_of_nth_char( start ), (text.index_of_nth_char( pre_chars + start ) - text.index_of_nth_char( start )) );
    var match_text = "<b>" + text_to_match + "</b>";
    var post_text  = text.substring( text.index_of_nth_char( end ), (text.index_of_nth_char( post_chars + end ) - text.index_of_nth_char( end )) );

    return( ((start == 0) ? "" : "…") + pre_text + match_text + post_text + "…" );

  }

  /* Adds the given match entry to the list of matching entries */
  private void add_match_entry( DBEntry entry ) {

    /* Populate the listbox */
    var label = new Label( "<b>" + entry.gen_title() + "</b>" ) {
      halign     = Align.START,
      hexpand    = true,
      use_markup = true,
      ellipsize  = Pango.EllipsizeMode.END
    };
    label.add_css_class( "listbox-head" );
    var text = new Label( get_matched_text( entry ) ) {
      halign     = Align.START,
      hexpand    = true,
      use_markup = true,
      ellipsize  = Pango.EllipsizeMode.END
    };
    var journal = new Label( entry.trash ? _journals.trash.name : entry.journal ) {
      halign  = Align.START,
      hexpand = true
    };
    var date = new Label( entry.date ) {
      halign  = Align.END,
      hexpand = true
    };
    var dbox = new Box( Orientation.HORIZONTAL, 0 ) {
      halign  = Align.FILL,
      hexpand = true
    };
    dbox.append( journal );
    dbox.append( date );
    var box = new Box( Orientation.VERTICAL, 2 ) {
      halign        = Align.FILL,
      hexpand       = true,
      width_request = 300,
      margin_top    = 5,
      margin_bottom = 5,
      margin_start  = 5,
      margin_end    = 5
    };
    box.append( label );
    if( text.label != "" ) {
      box.append( text );
    }
    box.append( dbox );
    _match_lb.append( box );

  }

}
