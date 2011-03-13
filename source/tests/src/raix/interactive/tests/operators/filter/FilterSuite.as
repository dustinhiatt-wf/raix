package raix.interactive.tests.operators.filter
{
	import raix.reactive.TimeStamped;
	
	[Suite]
	[RunWith("org.flexunit.runners.Suite")]
	public class FilterSuite
	{
		public var filter : FilterFixture;
		public var take : TakeFixture;
		public var first : FirstFixture;
		public var firstOrDefault : FirstOrDefaultFixture;
		public var single : SingleFixture;
		public var singleOrDefault : SingleOrDefaultFixture;
		public var last : LastFixture;
		public var lastOrDefault : LastOrDefaultFixture;
		public var defaultIfEmpty : DefaultIfEmptyFixture;
	}
}