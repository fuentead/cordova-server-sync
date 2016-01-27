package edu.berkeley.eecs.cordova.serversync;

import edu.berkeley.eecs.cordova.settings.ConnectionSettings;

public class CommunicationHelper {
    public static final String TAG = "CommunicationHelper";

    /*
     * Pushes the stats to the host.
     */
    public static void pushStats(Context cachedContext, String userToken,
                                 JSONObject appStats) throws IOException, JSONException {
        String commuteTrackerHost = ConnectionSettings.getConnectURL(cachedContext);
        edu.berkeley.eecs.cordova.comm.CommunicationHelper.pushJSON(
            cachedContext, commuteTrackerHost + "/stats/set", userToken, "stats", appStats);
    }

    /*
     * Gets user cache information from server
     */

    public static JSONArray server_to_phone(Context cachedContext, String userToken)
            throws IOException, JSONException {
        String commuteTrackerHost = ConnectionSettings.getConnectURL(cachedContext);
        String fullURL = commuteTrackerHost + "/usercache/get";
        String rawJSON = edu.berkeley.eecs.cordova.comm.CommunicationHelper.getUserPersonalData(cachedContext, fullURL, userToken);
        if (rawJSON.trim().length() == 0) {
            // We didn't get anything from the server, so let's return an empty array for now
            // TODO: Figure out whether we need to return a blank array from the server instead
            return new JSONArray();
        }
        JSONObject parentObj = new JSONObject(rawJSON);
        return parentObj.getJSONArray("server_to_phone");
    }

    /*
     * Pushes user cache to the server
     */
    public static void phone_to_server(Context cachedContext, String userToken, JSONArray entryArr)
            throws IOException, JSONException {
        String commuteTrackerHost = ConnectionSettings.getConnectURL(cachedContext);
        pushJSON(cachedContext, commuteTrackerHost + "/usercache/put",
                userToken, "phone_to_server", entryArr);
    }
}
