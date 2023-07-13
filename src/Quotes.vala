public class Quote {

  private string _quote  = "";
  private string _author = "";

  /* Default constructor */
  public Quote( string quote, string author = "" ) {
    _quote  = quote;
    _author = author;
  }

  /* Returns the given quote */
  public string make_quote() {
    if( _author == "" ) {
      return( _quote );
    } else {
      return( "\"%s\" — %s".printf( _quote, _author ) );
    }
  }

}

public class Quotes {

  private Array<Quote> _quotes;

  /* Default constructor */
  public Quotes() {

    _quotes = new Array<Quote>();

    add_quote( new Quote( _( "Journal writing, when it becomes a ritual for transformation, is not only life-changing but life-expanding." ), "Jen Williamson" ) );
    add_quote( new Quote( _( "Tell me about your day." ) ) );
    add_quote( new Quote( _( "Tell me what happened today." ) ) );
    add_quote( new Quote( _( "I want to know all about what happened to you today." ) ) );
    add_quote( new Quote( _( "Sometimes the only paper will listen to you." ), "Anonymous" ) );
    add_quote( new Quote( _( "Start writing, no matter what. The water does not flow until the faucet is turned on." ), "Louis L’Amour" ) );
    add_quote( new Quote( _( "I can shake off everything as I write; my sorrows disappear, my courage is reborn." ), "Anne Frank" ) );
    add_quote( new Quote( _( "Preserve your memories, keep them well, what you forget you can never retell." ), "Louisa May Alcott" ) );
    add_quote( new Quote( _( "Write about what really interests you, whether it is real things or imaginary things, and nothing else." ), "C. S. Lewis" ) );
    add_quote( new Quote( _( "I believe myself that a good writer doesn’t really need to be told anything except to keep at it." ), "Chinua Achebe" ) );
    add_quote( new Quote( _( "Writing is medicine." ), "Julia Cameron" ) );
    add_quote( new Quote( _( "I like to reserve the right to write about whatever I like." ), "David Sedaris" ) );
    add_quote( new Quote( _( "I write because I don’t know what I think until I read what I say." ), "Flannery O’Connor" ) );
    add_quote( new Quote( _( "Journaling is like whispering to one’s self and listening at the same time." ), "Mina Murray" ) );
    add_quote( new Quote( _( "Journal writing is a voyage to the interior." ), "Christina Baldwin" ) );
    add_quote( new Quote( _( "What would you write if you weren’t afraid?" ), "Mary Karr" ) );
    add_quote( new Quote( _( "There is no greater agony than bearing an untold story inside you." ), "Maya Angelou" ) );
    add_quote( new Quote( _( "A journal is your completely unaltered voice." ), "Lucy Dacus" ) );
    add_quote( new Quote( _( "Journaling helps you to remember how strong you truly are within yourself." ), "Asad Meah" ) );
    add_quote( new Quote( _( "People who keep journals have life twice." ), "Jessamyn West" ) );
    add_quote( new Quote( _( "Journal writing gives us insights into who we are, who we were, and who we can become." ), "Sandra Marinella" ) );
    add_quote( new Quote( _( "You can always edit a bad page. You can’t edit a blank page." ), "Jodi Picoult" ) );
    add_quote( new Quote( _( "It ain’t whatcha write, it’s the way atcha write it." ), "Jack Kerouac" ) );
    add_quote( new Quote( _( "If a nation loses its storytellers, it loses its childhood." ), "Peter Handke" ) );
    add_quote( new Quote( _( "Documenting little details of your everyday life becomes a celebration of who you are." ), "Carolyn V. Hamilton" ) );
    add_quote( new Quote( _( "Turning your journal time into a mini-ritual gives it importance." ), "Julie Hage" ) );
    add_quote( new Quote( _( "Your journal is your private sanctuary, your safe haven." ), "Julie Hage" ) );

  }

  /* Adds the given quote to the list */
  public void add_quote( Quote quote ) {
    _quotes.append_val( quote );
  }

  /* Returns a randomly selected quote */
  public string get_quote() {
    var index = Random.int_range( 0, (int)_quotes.length );
    return( _quotes.index( index ).make_quote() );
  }

}
