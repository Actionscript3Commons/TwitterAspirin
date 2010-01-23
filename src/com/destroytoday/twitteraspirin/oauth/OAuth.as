package com.destroytoday.twitteraspirin.oauth {
	import com.destroytoday.net.StringLoader;
	import com.destroytoday.net.XMLLoader;
	import com.destroytoday.pool.ObjectPool;
	import com.destroytoday.twitteraspirin.Twitter;
	import com.destroytoday.twitteraspirin.constants.TwitterError;
	import com.destroytoday.twitteraspirin.constants.TwitterURL;
	import com.destroytoday.twitteraspirin.net.LoaderFactory;
	import com.destroytoday.twitteraspirin.net.StringLoaderPool;
	import com.destroytoday.twitteraspirin.net.XMLLoaderPool;
	import com.destroytoday.twitteraspirin.signals.CallInfoSignal;
	import com.destroytoday.twitteraspirin.util.TwitterParser;
	import com.destroytoday.twitteraspirin.vo.UserVO;
	
	import flash.net.URLRequest;
	import flash.net.URLRequestMethod;
	
	import mx.utils.ObjectUtil;
	
	import org.iotashan.oauth.OAuthConsumer;
	import org.iotashan.oauth.OAuthRequest;
	import org.iotashan.oauth.OAuthSignatureMethod_HMAC_SHA1;
	import org.iotashan.oauth.OAuthToken;
	import org.iotashan.utils.OAuthUtil;
	import org.osflash.signals.Signal;

	/**
	 * The OAuth class handles authentication.
	 * @author Jonnie Hallman
	 */	
	public class OAuth {
		[Inject]
		public var loaderFactory:LoaderFactory;

		[Inject]
		public var accountCallsSignal:CallInfoSignal;
		
		/**
		 * @private 
		 */		
		protected var _requestTokenSignal:Signal = new Signal(OAuth, OAuthToken);
		
		/**
		 * @private 
		 */		
		protected var _accessTokenSignal:Signal = new Signal(OAuth, OAuthToken);
		
		/**
		 * @private 
		 */		
		protected var _verifyAccessTokenSignal:Signal = new Signal(OAuth, OAuthToken);
		
		/**
		 * @private 
		 */		
		protected var _errorSignal:Signal = new Signal(OAuth, String, String);
		
		/**
		 * @private 
		 */		
		protected var consumer:OAuthConsumer = new OAuthConsumer();
		
		/**
		 * @private 
		 */	
		protected var signature:OAuthSignatureMethod_HMAC_SHA1 = new OAuthSignatureMethod_HMAC_SHA1();
		
		/**
		 * @private 
		 */	
		protected var requestToken:OAuthToken;
		
		/**
		 * @private 
		 */	
		protected var _accessToken:OAuthToken;
		
		/**
		 * Instantiates the OAuth class.
		 * @param consumerKey the consumer key for the Twitter application
		 * @param consumerSecret the consumer secret for the Twitter application
		 */		
		public function OAuth(consumerKey:String = null, consumerSecret:String = null) {
			if (consumerKey && consumerSecret) {
				setConsumerCredentials(consumerKey, consumerSecret);
			}
		}
		
		//
		// Instance getters
		//
		
		/**
		 * The Signal that dispatches when the request token is returned.
		 * @return 
		 */		
		public function get requestTokenSignal():Signal {
			return _requestTokenSignal;
		}
		
		/**
		 * The Signal that dispatches when the access token is returned.
		 * @return 
		 */		
		public function get accessTokenSignal():Signal {
			return _accessTokenSignal;
		}
		
		/**
		 * The Signal that dispatches when the access token is verified.
		 * @return 
		 */		
		public function get verifyAccessTokenSignal():Signal {
			return _verifyAccessTokenSignal;
		}
		
		/**
		 * The Signal that dispatches when an OAuth error occurs.
		 * @return 
		 */		
		public function get errorSignal():Signal {
			return _errorSignal;
		}
		
		//
		// Property getters/setters
		//
		
		/**
		 * The access token for building requests. Setting it through its setter method skips verification.
		 * @return 
		 */		
		public function get accessToken():OAuthToken {
			return _accessToken;
		}
		
		/**
		 * 
		 * @param token
		 */		
		public function set accessToken(token:OAuthToken):void {
			_accessToken = token;
		}
		
		//
		// Methods
		//
		
		/**
		 * Sets the OAuth consumer credentials for the Twitter application.
		 * @param consumerKey the consumer key for the Twitter application
		 * @param consumerSecret the consumer secret for the Twitter application
		 */		
		public function setConsumerCredentials(consumerKey:String, consumerSecret:String):void {
			consumer.key = consumerKey;
			consumer.secret = consumerSecret;
		}
		
		/**
		 * Loads a request for the request token.
		 * @return the StringLoader loading the request
		 */		
		public function getRequestToken():StringLoader {
			var request:OAuthRequest = new OAuthRequest(URLRequestMethod.GET, TwitterURL.OAUTH_REQUEST_TOKEN, null, consumer);
			var loader:StringLoader = loaderFactory.getStringLoader(getRequestTokenHandler);
			
			loader.request.url = request.buildRequest(signature);
			
			loader.load();
			
			return loader;
		}
		
		/**
		 * Returns the authorize URL using the request token.
		 * This can only be called after first retrieving the request token.
		 * @return 
		 */		
		public function getAuthorizeURL():String {
			if (!requestToken) {
				_errorSignal.dispatch(this, TwitterError.OAUTH_AUTHORIZE_URL, "getAuthorizeURL() requires a request token");
				
				return null;
			}
			
			return TwitterURL.OAUTH_AUTHORIZE + "?oauth_token=" + requestToken.key;
		}
		
		/**
		 * Loads a request for the access token.
		 * @param pin the pin number provided by Twitter after navigating to the authorize URL
		 * @return the StringLoader loading the request
		 */		
		public function getAccessToken(pin:uint):StringLoader {
			if (!requestToken) {
				_errorSignal.dispatch(this, TwitterError.OAUTH_ACCESS_TOKEN, "getAccessToken(pin) requires a request token");
				
				return null;
			}

			var request:OAuthRequest = new OAuthRequest(URLRequestMethod.GET, TwitterURL.OAUTH_ACCESS_TOKEN, {oauth_verifier: pin}, consumer, requestToken);
			var loader:StringLoader = loaderFactory.getStringLoader(getAccessTokenHandler);
			
			loader.request.url = request.buildRequest(signature);
			
			loader.load();
			
			return loader;
		}
		
		/**
		 * Verifies an access token.
		 * If successful, Twitter returns the authenticated user's info.
		 * @param token the access token to verify
		 * @return the XMLLoader loading the verification
		 */		
		public function verifyAccessToken(token:OAuthToken):XMLLoader {
			_accessToken = token;
			
			var request:OAuthRequest = new OAuthRequest(URLRequestMethod.GET, TwitterURL.OAUTH_VERIFY_ACCESS_TOKEN, null, consumer, _accessToken);
			var loader:XMLLoader = loaderFactory.getXMLLoader(verifyAccessTokenHandler);
			
			loader.includeResponseInfo = false;
			loader.request.url = request.buildRequest(signature);
			
			loader.load();
			
			return loader;
		}
		
		public function parseURL(method:String, url:String, parameters:Object = null):String {
			return new OAuthRequest(method, url, parameters, consumer, _accessToken).buildRequest(new OAuthSignatureMethod_HMAC_SHA1());
		}
		
		/**
		 * @private
		 * @param loader the StringLoader instance
		 * @param data the request token data in string query format
		 */		
		protected function getRequestTokenHandler(loader:StringLoader, data:String):void {
			requestToken = OAuthUtil.getTokenFromResponse(data);

			_requestTokenSignal.dispatch(this, requestToken);
		}
		
		/**
		 * @private
		 * @param loader the StringLoader instance
		 * @param data the access token data in string query format
		 */		
		protected function getAccessTokenHandler(loader:StringLoader, data:String):void {
			_accessToken = OAuthUtil.getTokenFromResponse(data);
			
			_accessTokenSignal.dispatch(this, _accessToken);
		}
		
		/**
		 * @private
		 * @param loader the XMLLoader instance
		 * @param data the Twitter user data
		 */		
		protected function verifyAccessTokenHandler(loader:XMLLoader, data:XML):void {
			//var user:UserVO = TwitterParserUtil.parseUser(data);

			_verifyAccessTokenSignal.dispatch(this, _accessToken);
		}
	}
}