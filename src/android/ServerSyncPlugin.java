package edu.berkeley.eecs.emission.cordova.serversync;

import org.apache.cordova.*;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.accounts.Account;
import android.accounts.AccountManager;
import android.app.Activity;
import android.content.ContentResolver;
import android.content.Context;
import android.content.Intent;
import android.os.AsyncTask;
import android.os.Bundle;

import edu.berkeley.eecs.emission.R;
import edu.berkeley.eecs.emission.cordova.clientstats.ClientStatsHelper;
import edu.berkeley.eecs.emission.cordova.unifiedlogger.Log;

public class ServerSyncPlugin extends CordovaPlugin {

    // BEGIN: variables to set up the automatic syncing
    // The authority for the sync adapter's content provider
    public static final String AUTHORITY = "edu.berkeley.eecs.emission.provider";
    // An account type, in the form of a domain name
    public static final String ACCOUNT_TYPE = "eecs.berkeley.edu";
    // The account name
    public static final String ACCOUNT = "dummy_account";
    private Account mAccount;
    
    // Our ContentResolver is actually a dummy - does this matter?
    ContentResolver mResolver;
    
    private static final long SYNC_INTERVAL = 1 * 60 * 60; // Changed to 10 secs to debug syncing issues on some android version
    // END: variables to set up the automatic syncing

    private static String TAG = "ServerSyncPlugin";

    @Override
    protected void pluginInitialize() {
        mAccount = GetOrCreateSyncAccount(actv); 
        System.out.println("mAccount = "+mAccount);

        // TODO: In cfc_tracker but not in e_mission. Needed?
        mResolver = actv.getContentResolver();

        // Get the content resolver for your app
        // Turn on automatic syncing for the default account and authority
        ContentResolver.setIsSyncable(mAccount, AUTHORITY, 1);
        ContentResolver.setSyncAutomatically(mAccount, AUTHORITY, true);
        ContentResolver.addPeriodicSync(mAccount, AUTHORITY, new Bundle(), SYNC_INTERVAL);
    }

    @Override
    public boolean execute(String action, JSONArray data, CallbackContext callbackContext) throws JSONException {
            Activity actv = cordova.getActivity();

        if (action.equals("init")) {
            return true;
        } else if (action.equals("forceSync")) {
            Context ctxt = cordova.getActivity();
            Log.d(actv, TAG, "plugin.forceSync called");
            /* 
             * Calling forceSync so that we can know when the tasks is complete
             * and do a callback at that point.
             */
            ClientStatsHelper statsHelper = new ClientStatsHelper(ctxt);
            statsHelper.storeMeasurement(ctxt.getString(R.string.button_sync_forced), null,
                    String.valueOf(System.currentTimeMillis()));

            final CallbackContext cachedCallbackContext = callbackContext;
            AsyncTask<Context, Void, Void> task = new AsyncTask<Context, Void, Void>() {
                protected Void doInBackground(Context... ctxt) {
                    ServerSyncAdapter ssa = new ServerSyncAdapter(ctxt[0], true);
                    ssa.onPerformSync(mAccount, null, AUTHORITY,
                            null, null);
                    return null;
                }

                protected void onPostExecute(Long result) {
                    cachedCallbackContext.success();
                }
            };
            task.execute(actv);
            return true;
        } else {
            return false;
        }
    }

    public static Account GetOrCreateSyncAccount(Context context) {
    	// Get an instance of the Android account manager
    	AccountManager accountManager =
    			(AccountManager) context.getSystemService(
    					context.ACCOUNT_SERVICE);
    	Account[] existingAccounts = accountManager.getAccountsByType(ACCOUNT_TYPE);
    	assert(existingAccounts.length <= 1);
    	if (existingAccounts.length == 1) {
    		return existingAccounts[0];
    	}

    	// Create the account type and default account
    	Account newAccount = new Account(ACCOUNT, ACCOUNT_TYPE);	  
    	/*
    	 * Add the account and account type, no password or user data
    	 * If successful, return the Account object, otherwise report an error.
    	 */
    	if (accountManager.addAccountExplicitly(newAccount, null, null)) {
    		return newAccount;
    	} else {
    		System.err.println("Unable to create a dummy account to sync with!");
    		return null;
    	}
    }
}
