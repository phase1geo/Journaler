using Gtk;
using Granite;

public class Reviewer : Box {

  private MainWindow _win;
  private Journals   _journals;

  private MenuButton _journal_mb;
  private ListBox    _journal_lb;
  private Button     _journal_set_all;
  private Button     _journal_clear_all;
  private int        _num_journals = 0;

  private MenuButton _tag_mb;
  private ListBox    _tag_lb;
  private Button     _tag_set_all;
  private Button     _tag_clear_all;
  private int        _num_tags = 0;
  private bool       _ignore_toggled = false;

  private DateSelector _start_date;
  private DateSelector _end_date;

  private SearchEntry _search_entry;

  private ListBox                _match_lb;
  private Gee.ArrayList<DBEntry> _match_entries;

  public signal void show_matched_entry( DBEntry entry );
  public signal void close_requested();

  /* Default constructor */
  public Reviewer( MainWindow win, Journals journals ) {

    Object( orientation: Orientation.VERTICAL, spacing: 5, margin_start: 5, margin_end: 5, margin_top: 5, margin_bottom: 5 );

    _win           = win;
    _journals      = journals;
    _match_entries = new Gee.ArrayList<DBEntry>();

    /* Add the UI components */
    var lbox = new Box( Orientation.HORIZONTAL, 5 ) {
      homogeneous = true
    };

    var hbox = new Box( Orientation.HORIZONTAL, 5 );
    hbox.append( lbox );

    append( hbox );

    add_journal_list( lbox );
    add_tag_list( lbox );
    add_date_selector( hbox );
    add_close( hbox );
    add_search();

  }

  /* Creates the journal selection UI */
  private void add_journal_list( Box box ) {

    var label = new Label( Utils.make_title( _( "Journals:" ) ) ) {
      use_markup = true
    };

    _journal_lb = new ListBox();

    var lb_scroll = new ScrolledWindow() {
      valign            = Align.FILL,
      vexpand           = true,
      vscrollbar_policy = PolicyType.AUTOMATIC,
      child             = _journal_lb
    };

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

    var lbox = new Box( Orientation.VERTICAL, 5 ) {
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };
    lbox.set_size_request( -1, 400 );
    lbox.append( bbox );
    lbox.append( lb_scroll );

    var popover = new Popover() {
      has_arrow = false,
      child     = lbox
    };

    _journal_mb = new MenuButton() {
      halign  = Align.START,
      popover = popover
    };

    var jbox = new Box( Orientation.HORIZONTAL, 5 );
    jbox.append( label );
    jbox.append( _journal_mb );

    box.append( jbox );

  }

  /* Creates the tag selection UI */
  private void add_tag_list( Box box ) {

    var label = new Label( Utils.make_title( _( "Tags:" ) ) ) {
      use_markup = true
    };

    _tag_lb = new ListBox();

    var lb_scroll = new ScrolledWindow() {
      valign            = Align.FILL,
      vexpand           = true,
      vscrollbar_policy = PolicyType.AUTOMATIC,
      child             = _tag_lb
    };

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
    lbox.set_size_request( -1, 400 );
    lbox.append( bbox );
    lbox.append( lb_scroll );

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

    box.append( tbox );

  }

  /* Add the date selection UI */
  private void add_date_selector( Box box ) {

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

    box.append( dbox );

  }

  /* Adds a close button */
  private void add_close( Box box ) {

    var close_btn = new Button.from_icon_name( "window-close-symbolic" );
    close_btn.clicked.connect(() => {
      close_requested();
    });

    box.append( close_btn );

  }

  /* Add the search UI */
  private void add_search() {

    _search_entry = new SearchEntry() {
      halign  = Align.FILL,
      hexpand = true
    };
    _search_entry.search_changed.connect(() => {
      do_search();
    });

    append( _search_entry );

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
      var cb = (CheckButton)row.child;
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
  private void populate_journals() {

    clear_listbox( _journal_lb );

    /* Get the list of available journal names and sort them */
    var journals = new List<string>();
    for( int i=0; i<_journals.num_journals(); i++ ) {
      journals.append( _journals.get_journal( i ).name );
    }
    journals.sort( strcmp );

    foreach( var journal_name in journals ) {
      add_item_to_list( _journal_lb, journal_name, true );
    }
    add_item_to_list( _journal_lb, _journals.trash.name, false );

    _num_journals = (int)journals.length();

  }

  /* Grab the lastest tags */
  private void populate_tags() {

    clear_listbox( _tag_lb );

    /* Get the list of unique tags and sort them */
    var all_tags = new List<string>();
    for( int i=0; i<_journals.num_journals(); i++ ) {
      var journal = _journals.get_journal( i );
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
    all_tags.sort( strcmp );

    /* Populate the listbox */
    add_item_to_list( _tag_lb, _( "Untagged" ), true );
    foreach( var tag in all_tags ) {
      add_item_to_list( _tag_lb, tag, true );
    }

    _num_tags = (int)all_tags.length();

  }

  /* Initializes the dates in the range selectors */
  private void populate_dates() {

    _start_date.date = new GLib.DateTime.now_local();
    _end_date.date   = new GLib.DateTime.now_local();

  }

  /* Initializes the reviewer UI when this is shown */
  public void initialize() {

    /* Populate the journals and tags lists */
    populate_journals();
    populate_tags();
    populate_dates();

    _search_entry.text = "";

    /* Do an initial search */
    do_search();

  }

  /* This should be called prior to exiting the review mode. */
  public void on_close() {

    // TBD - We may not need this at this point

  }

  // --------------------------------------------------------------

  /* Creates the label that will be displayed on the journals or tags menubutton based on what is currently selected */
  private string make_menubutton_label( List<string> list, int max_length, string all_str, string none_str ) {
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
    get_activated_items_from_list( _journal_lb, ref journals );
    get_activated_items_from_list( _tag_lb,     ref tags );

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
      journal.db.query_entries( (journal_name == _journals.trash.name), tags, start_date, end_date, _search_entry.text, _match_entries );
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

  }

  // --------------------------------------------------------------

  /* Creates the sidebar where matched entries will be displayed */
  public Box create_reviewer_match_sidebar() {

    _match_lb = new ListBox() {
      show_separators = true,
      activate_on_single_click = true
    };

    _match_lb.row_selected.connect((row) => {
      _win.reset_timer();
      if( row == null ) {
        return;
      }
      var index = row.get_index();
      var entry = _match_entries.get( index );
      show_matched_entry( entry );
    });

    var lb_scroll = new ScrolledWindow() {
      hscrollbar_policy = PolicyType.NEVER,
      vscrollbar_policy = PolicyType.AUTOMATIC,
      halign            = Align.FILL,
      hexpand           = true,
      hexpand_set       = true,
      vexpand           = true,
      child             = _match_lb
    };
    lb_scroll.scroll_child.connect((t,h) => {
      _win.reset_timer();
      return( true );
    });

    var box = new Box( Orientation.VERTICAL, 0 ) {
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };
    box.append( lb_scroll );

    return( box );

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
    box.append( dbox );
    _match_lb.append( box );

  }

}
