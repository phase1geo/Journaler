public class GoalStreak : Goal {

  /* Default constructor */
  public GoalStreak( string name, int goal, bool word_count ) {
    base( name, goal, word_count );
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
