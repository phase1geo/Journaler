public class GoalStreak : Goal {

  /* Default constructor */
  public GoalStreak( string label, int goal, bool word_count ) {
    base( "streak-%d-%d".printf( goal, (word_count ? 1 : 0) ), label, goal, word_count );
  }

  /* Constructor */
  public GoalStreak.from_xml( Xml.Node* node ) {
    base.from_xml( node );
  }

  /* Returns the name of the XML node */
  public override string xml_node_name() {
    return( "goal-streak" );
  }

  /* Returns true if the count should be incremented */
  protected override CountAction get_count_action( Date start_date, Date todays_date, Date last_achieved ) {
    switch( last_achieved.days_between( todays_date ) ) {
      case 0 :  return( CountAction.NONE );
      case 1 :  return( CountAction.INCREMENT );
    }
    return( CountAction.RESET );
  }

}
