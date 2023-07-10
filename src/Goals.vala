public class Goals {

  private MainWindow  _win;
  private Array<Goal> _goals;
  private string      _start_date = DBEntry.todays_date();

  /* Default constructor */
  public Goals( MainWindow win ) {

    _win   = win;
    _goals = new Array<Goal>();

    for( int i=0; i<2; i++ ) {
      bool word_count = (i == 1);
      add_goal( new GoalStreak( _( "First Entry" ),         1, word_count ) );
      add_goal( new GoalStreak( _( "Two Days in a Row" ),   2, word_count ) );
      add_goal( new GoalStreak( _( "Three Days in a Row" ), 3, word_count ) );
      add_goal( new GoalStreak( _( "Five Days in a Row" ),  5, word_count ) );
      add_goal( new GoalStreak( _( "One Week in a Row" ),   days_in_week( 1 ),  word_count ) );
      add_goal( new GoalStreak( _( "Two Weeks in a Row" ),  days_in_week( 2 ),  word_count ) );
      add_goal( new GoalStreak( _( "One month in a Row" ),  days_in_month( 1 ), word_count ) );
      add_goal( new GoalStreak( _( "Two months in a Row" ), days_in_month( 2 ), word_count ) );
      add_goal( new GoalStreak( _( "Six months in a Row" ), days_in_month( 6 ), word_count ) );
      add_goal( new GoalStreak( _( "One year in a Row" ),   days_in_year( 1 ),  word_count ) );
      add_goal( new GoalStreak( _( "Two years in a Row" ),  days_in_year( 2 ),  word_count ) );
      add_goal( new GoalStreak( _( "Five years in a Row" ), days_in_year( 5 ),  word_count ) );
    }

  }

  /* Adds a new goal to the list */
  private void add_goal( Goal goal ) {
    _goals.append_val( goal );
  }

  /* Checks for any achievements when an entry meets an entry goal (on save only) */
  public void mark_achievement( string entry_date, bool word_count_met ) {
    var todays_date = DBEntry.todays_date();
    if( todays_date == entry_date ) {
      string[] notify_msgs = {};
      bool     save_needed = false;
      for( int i=0; i<_goals.length; i++ ) {
        bool achieved;
        save_needed |= _goals.index( i ).mark_achievement( _start_date, todays_date, word_count_met, out achieved );
        if( achieved ) {
          notify_msgs += _goals.index( i ).name;
        }
      }
      if( save_needed ) {
        save();
      }
      if( notify_msgs.length == 1 ) {
        _win.notification( _( "New Reward Achieved!" ), notify_msgs[0] );
      } else if( notify_msgs.length > 1 ) {
        _win.notification( _( "New Rewards Achieved!" ), string.joinv( "\n", notify_msgs ) );
      }
    }
  }

  /* Returns the number of days in a week */
  private int days_in_week( int num_weeks ) {
    return( 7 * num_weeks );
  }

  /* Returns the average number of days in a month */
  private int days_in_month( int num_months ) {
    return( 30 * num_months );
  }

  /* Returns the number of days in a year */
  private int days_in_year( int num_years ) {
    return( 365 * num_years );
  }

  /* Returns the pathname of the XML file */
  private string xml_file() {
    return( GLib.Path.build_filename( Environment.get_user_data_dir(), "journaler", "goals.xml" ) );
  }

  /* Saves the goal information in XML format */
  public void save() {

    Xml.Doc*  doc  = new Xml.Doc( "1.0" );
    Xml.Node* root = new Xml.Node( null, "goals" );

    root->set_prop( "version", Journaler.version );

    for( int i=0; i<_goals.length; i++ ) {
      root->add_child( _goals.index( i ).save() );
    }

    doc->set_root_element( root );
    doc->save_format_file( xml_file(), 1 );

    delete doc;

  }

  /* Loads the stored goal information in XML format */
  public void load() {

    Xml.Doc* doc = Xml.Parser.read_file( xml_file(), null, (Xml.ParserOption.HUGE | Xml.ParserOption.NOWARNING) );
    if( doc == null ) {
      return;
    }

    Xml.Node* root = doc->get_root_element();

    var verson = root->get_prop( "version" );
    if( verson != null ) {
      check_version( verson );
    }

    for( Xml.Node* it = doc->get_root_element()->children; it != null; it = it->next ) {
      if( it->type == Xml.ElementType.ELEMENT_NODE ) {
        // TBD
      }
    }

    delete doc;

  }

  /* Allows us to make upgrades based on version information */
  private void check_version( string version ) {

    // TBD

  }

}
