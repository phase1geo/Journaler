public enum CountAction {
  NONE,
  INCREMENT,
  RESET
}

public class Goal {

  private string _name       = "";
  private bool   _achieved   = false;
  private bool   _word_count = false;

  protected int    count         { set; get; default = 0; }
  protected int    goal          { set; get; default = 0; }
  protected string last_achieved { set; get; default = DBEntry.todays_date(); }

  public string name {
    get {
      return( _name );
    }
  }
  public bool achieved {
    get {
      return( _achieved );
    }
  }

  /* Default constructor */
  public Goal( string name, int goal, bool word_count ) {
    _name       = name;
    _goal       = goal;
    _word_count = word_count;
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
    if( (word_count_met == _word_count) && !_achieved ) {
      var save = true;
      switch( get_count_action( get_date( start_date ), get_date( todays_date ), get_date( last_achieved ) ) ) {
        case CountAction.INCREMENT :  count++;        break;
        case CountAction.RESET     :  count = 1;      break;
        default                    :  save  = false;  break;
      }
      last_achieved = todays_date;
      if( count >= goal ) {
        _achieved = true;
      }
      achievement = _achieved;
      return( save );
    }
    return( false );
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

  /* Callback method used for saving local data */
  protected virtual void save_node( Xml.Node* node ) {}

  /* Callback method used for loading local data */
  protected virtual void load_node( Xml.Node* node ) {}

  /* Save method to override */
  public Xml.Node* save() {

    Xml.Node* node = new Xml.Node( null, xml_node_name() );

    node->set_prop( "name",          _name );
    node->set_prop( "achieved",      _achieved.to_string() );
    node->set_prop( "word_count",    _word_count.to_string() );
    node->set_prop( "count",         count.to_string() );
    node->set_prop( "goal",          goal.to_string() );
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

    var wc = node->get_prop( "word_count" );
    if( wc != null ) {
      _word_count = bool.parse( wc );
    }

    var c = node->get_prop( "count" );
    if( c != null ) {
      count = int.parse( c );
    }

    var g = node->get_prop( "goal" );
    if( g != null ) {
      goal = int.parse( g );
    }

    var la = node->get_prop( "last_achieved" );
    if( la != null ) {
      last_achieved = la;
    }

    load_node( node );

  }

}
