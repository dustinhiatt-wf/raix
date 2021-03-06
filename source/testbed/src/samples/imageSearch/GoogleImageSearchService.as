package samples.imageSearch
{
	import flash.net.URLRequest;
	
	import mx.controls.Image;
	
	import raix.reactive.*;
	
	public class GoogleImageSearchService
	{
		private var _jsonService : JsonService = new JsonService();
		
		public function GoogleImageSearchService()
		{
		}
		
		public function getObservable(searchTerm : String) : IObservable
		{
			var urlRequest : URLRequest = getGisUrlRequest(searchTerm);
			
			return _jsonService.getObservable(urlRequest)
			 	.mapMany(Object, function(result:Object) : IObservable
				{
					return Observable.fromArray(Object, result.responseData.results);
				})
				.map(ImageResult, function(result:Object) : ImageResult
				{
					return new ImageResult(
						result.url,
						result.tbUrl,
						result.titleNoFormatting);
				});
		}
		
		private function getGisUrlRequest(searchTerm : String) : URLRequest
		{
			var encodedSearchTerm : String = searchTerm; // TODO
			
			var urlRequest : URLRequest = new URLRequest();
			urlRequest.url ="http://ajax.googleapis.com/ajax/services/search/images?v=1.0&q=" + 
				encodedSearchTerm;
				
			return urlRequest;
		}

	}
}