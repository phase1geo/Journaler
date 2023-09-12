/*
 Over 1, 2, 3, 6, 9, and 12 months:
 - 2x a week  2 in 7 over X
 - 3x a week  3 in 7 over X
 - 5x a week  5 in 7 over X
 - 5x a month 5 in 30 over X
 - 10x a month 10 in 30 over X
 - 20x a month 20 in 30 over X
*/

public enum SubGoalDuration {
  WEEK,
  MONTH;

  public string name() {
    switch( this ) {
      case WEEK  :  return( "w" );
      case MONTH :  return( "m" );
      default    :  assert_not_reached();
    }
  }
}

public class GoalMinimum : Goal {

  private int             _sub_count    = 0;
  private int             _sub_goal     = 0;
  private SubGoalDuration _sub_duration = SubGoalDuration.WEEK;

  /* Default constructor */
  public GoalMinimum( string label, int sub_goal, SubGoalDuration sub_duration, int goal ) {
    base( "minimum-%d-%d%s".printf( goal, sub_goal, sub_duration.name() ), label, goal );
    _sub_goal     = sub_goal;
    _sub_duration = sub_duration;
  }

  /* Constructor */
  public GoalMinimum.from_xml( Xml.Node* node ) {
    base.from_xml( node );
  }

  /* Calculates the beginning of the week */
  private Date get_beginning_of_this_week( Date begin_date ) {
    var begin_week = begin_date;
    switch( begin_date.get_weekday() ) {
      case DateWeekday.SUNDAY    :  begin_week.subtract_days( 0 );  break;
      case DateWeekday.MONDAY    :  begin_week.subtract_days( 1 );  break;
      case DateWeekday.TUESDAY   :  begin_week.subtract_days( 2 );  break;
      case DateWeekday.WEDNESDAY :  begin_week.subtract_days( 3 );  break;
      case DateWeekday.THURSDAY  :  begin_week.subtract_days( 4 );  break;
      case DateWeekday.FRIDAY    :  begin_week.subtract_days( 5 );  break;
      case DateWeekday.SATURDAY  :  begin_week.subtract_days( 6 );  break;
      default                    :  assert_not_reached();
    }
    return( begin_week );
  }

  /* Calculates the beginning of the previous week */
  private Date get_beginning_of_previous_week( Date begin_date ) {
    var begin_week = begin_date;
    begin_week.subtract_days( 7 );
    return( begin_week );
  }

  /* Calculates the beginning of the month */
  private Date get_beginning_of_this_month( Date begin_date ) {
    var begin_mon = begin_date;
    begin_mon.subtract_days( begin_date.get_day() - 1 );
    return( begin_mon );
  }

  /* Calculates the beginning of the previous month */
  private Date get_beginning_of_previous_month( Date begin_date ) {
    var begin_mon = begin_date;
    begin_mon.subtract_months( 1 );
    return( begin_mon );
  }

  /*
   USEFUL FOR DEBUGGING
  private string date_string( Date date ) {
    return( "%04u-%02u-%02u".printf( date.get_year(), date.get_month(), date.get_day() ) );
  }
  */

  /* Returns the count action based on the status of the subgoal */
  protected override CountAction get_count_action( Date todays_date, Date last_achieved ) {

    Date beginning_of_this;
    Date beginning_of_last;

    /* Get the beginning of the current and previous periods */
    if( _sub_duration == SubGoalDuration.WEEK ) {
      beginning_of_this = get_beginning_of_this_week( todays_date );
      beginning_of_last = get_beginning_of_previous_week( beginning_of_this );
    } else {
      beginning_of_this = get_beginning_of_this_month( todays_date );
      beginning_of_last = get_beginning_of_previous_month( beginning_of_this );
    }

    /*
     If we are still within the same week as the last_sub, increment our subcount and see if we have met the sub-goal.
     Increment the main counter if we have met the sub-goal.
    */
    if( beginning_of_this.compare( last_achieved ) <= 0 ) {
      if( ++_sub_count == _sub_goal ) {
        return( CountAction.INCREMENT );
      }

    /* If we hit the last subgoal and are starting on the new period, either increment or do nothing */
    } else if( (beginning_of_last.compare( last_achieved ) <= 0) && (_sub_count >= _sub_goal) ) {
      _sub_count = 0;
      if( ++_sub_count == _sub_goal ) {
        return( CountAction.INCREMENT );
      }

    /* Otherwise, we need to reset */
    } else {
      _sub_count = 0;
      if( ++_sub_count == _sub_goal ) {
        return( CountAction.RESET );
      }
      return( CountAction.CLEAR );
    }

    return( CountAction.NONE );

  }

  /* Returns the XML node name used to store results */
  public override string xml_node_name() {
    return( "goal-minimum" );
  }

  /* Callback method used for merging local data */
  protected override void do_merge( Goal goal ) {
    var min_goal = (GoalMinimum)goal;
    _sub_count = min_goal._sub_count;
  }

  /* Callback method used for saving local data */
  protected override void save_node( Xml.Node* node ) {
    node->set_prop( "sub-count", _sub_count.to_string() );
  }

  /* Callback method used for loading local data */
  protected override void load_node( Xml.Node* node ) {

    var sc = node->get_prop( "sub-count" );
    if( sc != null ) {
      _sub_count = int.parse( sc );
    }

  }

}
