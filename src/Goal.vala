public enum CountAction {
  NONE,
  INCREMENT,
  RESET
}

public class Goal {

  private string _name       = "";
  private string _label      = "";
  private bool   _achieved   = false;
  private bool   _word_count = false;

  protected string last_achieved { set; get; default = DBEntry.yesterdays_date(); }

  public string name {
    get {
      return( _name );
    }
  }
  public string label {
    get {
      return( _label );
    }
  }
  public bool achieved {
    get {
      return( _achieved );
    }
  }
  public int count { set; get; default = 0; }
  public int goal  { set; get; default = 0; }

  /* Default constructor */
  public Goal( string name, string label, int goal, bool word_count ) {
    _name       = name;
    _label      = label;
    _goal       = goal;
    _word_count = word_count;
  }

  /* Constructor */
  public Goal.from_xml( Xml.Node* node ) {
    load( node );
  }

  /* Returns true if the count should be incremented */
  protected virtual CountAction get_count_action( Date start_date, Date todays_date, Date last_achieved ) {
    return( CountAction.NONE );
  }

  /*
   This should be called whenver an entry goal has been met.  It will return true if the goal requires
   saving.
  */
  public bool mark_achievement( string start_date, string todays_date, bool word_count_met, out bool achievement ) {
    achievement = false;
    stdout.printf( "In mark_achievement, name: %s, word_count_met: %s, word_count: %s, count: %d, achieved: %s\n",
                   _name, word_count_met.to_string(), _word_count.to_string(), count, _achieved.to_string() );
    if( (word_count_met == _word_count) && !_achieved ) {
      var save = true;
      switch( get_count_action( get_date( start_date ), get_date( todays_date ), get_date( last_achieved ) ) ) {
        case CountAction.INCREMENT :  count++;        break;
        case CountAction.RESET     :  count = 1;      break;
        default                    :  save  = false;  break;
      }
      stdout.printf( "  count: %d, goal: %d, save: %s\n", count, goal, save.to_string() );
      last_achieved = todays_date;
      if( count >= goal ) {
        _achieved = true;
      }
      achievement = _achieved;
      return( save );
    }
    return( false );
  }

  /* Returns the completion percentage of this goal */
  public int completion_percentage() {
    return( (int)((count / (float)goal) * 100) );
  }

  /* Gets the date from the given date string */
  protected Date get_date( string date_str ) {
    Date date = {};
    var  parts = date_str.split( "-" );
    date.clear();
    date.set_dmy( (DateDay)int.parse( parts[2] ), int.parse( parts[1] ), (DateYear)int.parse( parts[0] ) );
    return( date.copy() );
  }

  /* Returns the XML node name used to store results */
  public virtual string xml_node_name() {
    return( "goal-generic" );
  }

  /* Callback method used for merging local data */
  protected virtual void do_merge( Goal goal ) {}

  /* Used to merge the loaded XML data into this goal */
  public void merge( Goal goal ) {

    _achieved     = goal._achieved;
    count         = goal.count;
    last_achieved = goal.last_achieved;

    do_merge( goal );

  }

  /* Callback method used for saving local data */
  protected virtual void save_node( Xml.Node* node ) {}

  /* Callback method used for loading local data */
  protected virtual void load_node( Xml.Node* node ) {}

  /* Save method to override */
  public Xml.Node* save() {

    Xml.Node* node = new Xml.Node( null, xml_node_name() );

    node->set_prop( "name",          _name );
    node->set_prop( "achieved",      _achieved.to_string() );
    node->set_prop( "count",         count.to_string() );
    node->set_prop( "last_achieved", last_achieved );

    save_node( node );

    return( node );

  }

  /* Load method to override */
  public void load( Xml.Node* node ) {

    var n = node->get_prop( "name" );
    if( n != null ) {
      _name = n;
    }

    var a = node->get_prop( "achieved" );
    if( a != null ) {
      _achieved = bool.parse( a );
    }

    var c = node->get_prop( "count" );
    if( c != null ) {
      count = int.parse( c );
    }

    var la = node->get_prop( "last_achieved" );
    if( la != null ) {
      last_achieved = la;
    }

    load_node( node );

  }

}
