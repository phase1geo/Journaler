using Gtk;

/* Helper class for matched entries */
public class JournalEntry {
  public string   journal { set; get; default = ""; }
  public DBEntry? entry   { set; get; default = null; }

  public JournalEntry( string journal, DBEntry entry ) {
    this.journal = journal;
    this.entry   = entry;
  }
}

public class Reviewer : Box {

  private MainWindow _win;
  private Journals   _journals;

  private MenuButton _journal_mb;
  private ListBox    _journal_lb;
  private int        _num_journals = 0;

  private MenuButton _tag_mb;
  private ListBox    _tag_lb;
  private int        _num_tags = 0;

  private ListBox        _match_lb;
  private Array<DBEntry> _match_entries;

  private Gee.HashMap<string,Array<DBEntry> > _all_entries;

  public signal void show_matched_entry( DBEntry entry );

  /* Default constructor */
  public Reviewer( MainWindow win, Journals journals ) {

    Object( orientation: Orientation.HORIZONTAL, spacing: 5, margin_start: 5, margin_end: 5, margin_top: 5, margin_bottom: 5 );

    _win           = win;
    _journals      = journals;
    _all_entries   = new Gee.HashMap<string,Array<DBEntry> >();
    _match_entries = new Array<DBEntry>();

    /* Add the UI components */
    add_journal_list();
    add_tag_list();
    add_date_selector();
    add_search();

  }

  /* Creates the journal selection UI */
  private void add_journal_list() {

    _journal_lb = new ListBox();

    var lb_scroll = new ScrolledWindow() {
      valign            = Align.FILL,
      vexpand           = true,
      vscrollbar_policy = PolicyType.AUTOMATIC,
      child             = _journal_lb
    };

    var set_all = new Button.with_label( _( "Select All" ) ) {
      halign  = Align.START,
      hexpand = true
    };
    set_all.clicked.connect(() => {
      _win.reset_timer();
      change_select_of_all_items( _journal_lb, true );
    });

    var clear_all = new Button.with_label( _( "Clear All" ) ) {
      halign  = Align.END,
      hexpand = true
    };
    clear_all.clicked.connect(() => {
      _win.reset_timer();
      change_select_of_all_items( _journal_lb, false );
    });

    var bbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign  = Align.FILL,
      hexpand = true
    };
    bbox.append( set_all );
    bbox.append( clear_all );

    var box = new Box( Orientation.VERTICAL, 5 ) {
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };
    box.set_size_request( -1, 400 );
    box.append( bbox );
    box.append( lb_scroll );

    var popover = new Popover() {
      child = box
    };

    _journal_mb = new MenuButton() {
      label   = _( "All Journals" ),
      popover = popover
    };

    append( _journal_mb );

  }

  /* Creates the tag selection UI */
  private void add_tag_list() {

    _tag_lb = new ListBox();

    var lb_scroll = new ScrolledWindow() {
      valign            = Align.FILL,
      vexpand           = true,
      vscrollbar_policy = PolicyType.AUTOMATIC,
      child             = _tag_lb
    };

    var set_all = new Button.with_label( _( "Select All" ) ) {
      halign  = Align.START,
      hexpand = true
    };
    set_all.clicked.connect(() => {
      _win.reset_timer();
      change_select_of_all_items( _tag_lb, true );
    });

    var clear_all = new Button.with_label( _( "Clear All" ) ) {
      halign  = Align.END,
      hexpand = true
    };
    clear_all.clicked.connect(() => {
      _win.reset_timer();
      change_select_of_all_items( _tag_lb, false );
    });

    var bbox = new Box( Orientation.HORIZONTAL, 5 ) {
      halign  = Align.FILL,
      hexpand = true
    };
    bbox.append( set_all );
    bbox.append( clear_all );

    var box = new Box( Orientation.VERTICAL, 5 ) {
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };
    box.set_size_request( -1, 400 );
    box.append( bbox );
    box.append( lb_scroll );

    var popover = new Popover() {
      child = box
    };

    _tag_mb = new MenuButton() {
      label   = _( "All Tags" ),
      popover = popover
    };

    append( _tag_mb );

  }

  /* Add the date selection UI */
  private void add_date_selector() {

    // TBD

  }

  /* Add the search UI */
  private void add_search() {

    // TBD

  }

  /* Adds the given label as a checkbutton to the list */
  private void add_item_to_list( ListBox lb, string label ) {

    var btn = new CheckButton.with_label( label ) {
      active        = true,
      margin_start  = 5,
      margin_end    = 5,
      margin_top    = 5,
      margin_bottom = 5
    };
    btn.activate.connect(() => {
      _win.reset_timer();
      do_search();
    });
    btn.toggled.connect(() => {
      _win.reset_timer();
      do_search();
    });

    lb.append( btn );

  }

  /* Gathers the list of all activated items from the given list */
  private void get_activated_items_from_list( ListBox lb, Array<string> items ) {

    var i   = 0;
    var row = lb.get_row_at_index( i++ );

    while( row != null ) {
      var cb = (CheckButton)row.child;
      if( cb.active ) {
        items.append_val( cb.label );
      }
      row = lb.get_row_at_index( i++ );
    }

  }

  /* Selects all of the items in the list and perform a search, if necessary */
  private void change_select_of_all_items( ListBox lb, bool select ) {

    var i          = 0;
    var row        = lb.get_row_at_index( i++ );
    var run_search = false;

    while( row != null ) {
      var cb = (CheckButton)row.child;
      if( cb.active != select ) {
        cb.active  = select;
        run_search = true;
      }
      row = lb.get_row_at_index( i++ );
    }

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

  private void display_string_array( string msg, List<string> arr ) {
    stdout.printf( "%s\n", msg );
    foreach( var item in arr ) {
      stdout.printf( "  %s\n", item );
    }
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
      add_item_to_list( _journal_lb, journal_name );
    }

    _num_journals = (int)journals.length;

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
    add_item_to_list( _tag_lb, _( "Untagged" ) );
    foreach( var tag in all_tags ) {
      add_item_to_list( _tag_lb, tag );
    }

    _num_tags = (int)all_tags.length();

  }

  /* Initializes the reviewer UI when this is shown */
  public void initialize() {

    /* Populate the journals and tags lists */
    populate_journals();
    populate_tags();

    /* Populate the all entries list */
    _all_entries.clear();
    for( int i=0; i<_journals.num_journals(); i++ ) {
      var journal = _journals.get_journal( i );
      var entries = new Array<DBEntry>();
      journal.db.get_all_entries( entries );
      _all_entries.set( journal.name, entries );
    }

    /* Do an initial search */
    do_search();

  }

  // --------------------------------------------------------------

  /* Performs search of selected items, date ranges, and search terms */
  private void do_search() {

    var journals = new Array<string>();
    var tags     = new Array<string>();

    /* Get the selected journals and tags */
    get_activated_items_from_list( _journal_lb, journals );
    get_activated_items_from_list( _tag_lb,     tags );

    /* Clear the list of match entries */
    clear_listbox( _match_lb );
    _match_entries.remove_range( 0, _match_entries.length );

    /* Add the matching entries to the list */
    var journal_entries = new List<JournalEntry>();
    for( int i=0; i<journals.length; i++ ) {
      var journal = journals.index( i );
      var entries = _all_entries.get( journal );
      for( int j=0; j<entries.length; j++ ) {
        var entry = entries.index( j );
        for( int k=0; k<tags.length; k++ ) {
          var tag = tags.index( k );
          if( ((tag == _( "Untagged" )) ? (entry.tags.length() == 0) : entry.contains_tag( tag )) && true /* Include date and search criteria here */ ) {
            var journal_entry = new JournalEntry( journal, entry );
            journal_entries.append( journal_entry );
          }
        }
      }
    }

    /* Sort the entries */
    journal_entries.sort((a, b) => {
      var date_match = strcmp( b.entry.date, a.entry.date );
      if( date_match == 0 ) {
        return( strcmp( a.journal, b.journal ) );
      }
      return( date_match );
    });

    /* Add the entries */
    foreach( var journal_entry in journal_entries ) {
      add_match_entry( journal_entry.journal, journal_entry.entry );
    }

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
      /*
      if( _ignore_select || (row == null) ) {
        return;
      }
      */
      var index = row.get_index();
      show_matched_entry( _match_entries.index( index ) );
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
  private void add_match_entry( string journal_name, DBEntry entry ) {

    /* Populate the listbox */
    var label = new Label( "<b>" + entry.gen_title() + "</b>" ) {
      halign     = Align.START,
      hexpand    = true,
      use_markup = true,
      ellipsize  = Pango.EllipsizeMode.END
    };
    label.add_css_class( "listbox-head" );
    var journal = new Label( journal_name ) {
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

    _match_entries.append_val( entry );

  }

}
