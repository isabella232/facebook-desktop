package com.facebook.desktop.control.api
{
	import com.facebook.desktop.control.notification.ToastManager;
	import com.facebook.desktop.model.Model;
	import com.facebook.desktop.model.cache.UserCache;
	import com.facebook.graph.FacebookDesktop;
	
	import mx.logging.ILogger;
	import mx.logging.Log;
	import mx.resources.ResourceManager;

	public class GetStreamUpdates
	{
		private static const API_CALL:String = "fql.query";
		
		private static var model:Model = Model.instance;
		private static var logger:ILogger = Log.getLogger("com.facebook.desktop.control.api.GetStreamUpdates");
		
		private var userCache:UserCache = UserCache.instance;
		
		public var previousUpdateTime:String;
		
		public function execute(callback:Function = null):void
		{
			var query:String = "SELECT created_time, actor_id, target_id, message, permalink FROM stream WHERE filter_key = 'nf' AND created_time >= " + previousUpdateTime + " ORDER BY created_time DESC";
			
			FacebookDesktop.callRestAPI(API_CALL, handler, {query: query});
			
			function handler(updates:Object, fail:Object):void
			{
				if (model.preferences.showStoryUpdates && updates is Array && (updates as Array).length > 0)
				{
					for (var i:int = 0; i < updates.length; i++)
					{
						var update:Object = updates[i];
						var uids:String = update.actor_id;
						
						// construct uids arg for getInfo call
						if (update.target_id != null)
						{
							uids += ", " + update.target_id;
						}  // if statement
						
						// put in generic message for blank updates
						if (update.message == null || update.message == "")
						{
							update.message = ResourceManager.getInstance().getString("resources", "toast.someonePostedStory");
						}  // if statement
						
						makeToast(uids, update.message, update.permalink, (i == (updates.length - 1)) ? true : false);
					}  // for loop
					
					model.latestStreamUpdate = updates[0].created_time;
				}  // if statement
				else if (fail != null)
				{
					logger.error("Error fetching stream updates!  Error: " + fail);
				}  // else statement
				
				if (callback != null)
				{
					callback(updates, fail);
				}  // if statement
			}  // handler
			
			function makeToast(uids:String, message:String, permalink:String, last:Boolean):void
			{
				var getUserInfoCommand:GetUserInfo = new GetUserInfo();
				getUserInfoCommand.fields = "name, pic_square";
				getUserInfoCommand.uids = uids;
				getUserInfoCommand.execute(getUserInfoHandler);
				
				function getUserInfoHandler(result:Object = null, fail:Object = null):void
				{
					var uidsArray:Array = uids.split(", ");
					
					if (uidsArray.length > 1)
					{
						var actorId:String = uidsArray[0];
						var targetId:String = uidsArray[1];
						
						logger.info("Story update! - " + userCache.get(actorId).name + " ► " + userCache.get(targetId).name + " - " + message);
						ToastManager.queueToast(userCache.get(actorId).name + " ► " + userCache.get(targetId).name, message, permalink, userCache.get(actorId).picSquare);
					}  // if statement
					else
					{
						logger.info("Story update! - " + userCache.get(uids).name + " " + message);
						ToastManager.queueToast(userCache.get(uids).name, message, permalink, userCache.get(uids).picSquare);
					}  // else statement
					
					if (last)
					{
						ToastManager.showAll();
					}  // if statement
				}  // getInfoSuccessHandler
				
				function getInfoErrorHandler():void
				{
					logger.error("Error getting user info for toast");
				}  // getInfoErrorHandler
			}  // makeToast
		}  // execute
	}
}