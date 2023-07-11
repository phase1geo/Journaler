public class GoalCount : Goal {

  /* Default constructor */
  public GoalCount( string label, int goal, bool word_count ) {
    base( "count-%d-%d".printf( goal, (word_count ? 1 : 0) ), label, goal, word_count );
  }

  /* Constructor */
  public GoalCount.from_xml( Xml.Node* node ) {
    base.from_xml( node );
  }

  /* Returns the name of the XML node */
  public override string xml_node_name() {
    return( "goal-count" );
  }

  /* Returns true if the count should be incremented */
  protected override CountAction get_count_action( Date todays_date, Date last_achieved ) {
    return( (last_achieved.days_between( todays_date ) == 0) ? CountAction.NONE : CountAction.INCREMENT );
  }

}
