#include <sourcemod>

int roundCount = 0;
int voteRound = 0;

Handle hRestartGame = INVALID_HANDLE;
char ChatPrefix1[18] = "\x01[Server]\x04";
char ChatPrefix2[18] = "\x01[Server]\x02";


public Plugin myinfo =
{
	name = "Round Restore",
	author = "Moritz Loewenstein",
	description = "Restore round backups with sourcemod",
	version = "0.9",
	url = "https://github.com/MoritzLoewenstein/RoundRestore"
};

public void OnPluginStart() {
	/* Hooks */
	HookEvent("cs_match_end_restart", Event_CsMatchEndRestart);
	HookEvent("round_start", Event_RoundStart);
	/* Plugin Commands */
	RegAdminCmd("sm_restore", MainMenu, ADMFLAG_GENERIC, "[RR] Displays the Round Restore menu");
	RegAdminCmd("sm_restorelast", VoteLast, ADMFLAG_GENERIC, "[RR] Displays the Round Restore menu");
	/* mp_restartgame Hook */
	hRestartGame = FindConVar("mp_restartgame");
	if(hRestartGame != INVALID_HANDLE) {
		HookConVarChange(hRestartGame, GameRestartChanged);
	}
	ServerCommand("mp_backup_restore_load_autopause 0");
	ServerCommand("mp_backup_round_auto 1");
	PrintToChatAll("%s Round Restore loaded!", ChatPrefix1);
}

public void OnMapStart() {
	roundCount = 0;
}
public void Event_CsMatchEndRestart(Event event, const char[] name, bool dontBroadcast) {
	roundCount = 0;
	PrintToChatAll("%s Game restarting", ChatPrefix1);
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast) {
	roundCount ++;
}

public void GameRestartChanged(Handle convar, const char[] oldValue, const char[] newValue) {
	if(!StrEqual(newValue, "0")) {
		roundCount = 0;
		PrintToChatAll("%s Starting Game", ChatPrefix1);
	}
}

public int MenuHandler(Menu menu, MenuAction action, int param1, int param2) {
	if (action == MenuAction_Select) {
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		if (StrEqual(info, "restoreLast")) {
			VoteLast(param1, 20);
		}
		else if (StrEqual(info, "restoreOther")) {
			VoteOther(param1, roundCount);
		}
	}
	else if (action == MenuAction_Cancel) {
		PrintToChat(param1, "%s Menu cancelled", ChatPrefix2);
	}
	else if (action == MenuAction_End) {
		delete menu;
	}
}

public Action MainMenu(int client, int args) {
	Menu menu = new Menu(MenuHandler);
	menu.SetTitle("Round Restore");
	menu.ExitButton = true;
	menu.AddItem("restoreLast", "Restore last Round");
	menu.AddItem("restoreOther", "Restore other Rounds");
	menu.Display(client, 20);
	return Plugin_Handled;
}

public int Handle_VoteRound(Menu menu, MenuAction action, int param1,int param2) {
	if (action == MenuAction_Select) {
		if (param2 == 0) {
			PrintToChat(param1, "%s Vote successfull", ChatPrefix1);
			restoreRound(voteRound);
		}
		else PrintToChat(param1, "%s Vote cancelled.", ChatPrefix2);
	}
	else if (action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			MainMenu(param1, 20);
		}
		else
			PrintToChat(param1, "%s Menu cancelled.", ChatPrefix2);
	}
	else if (action == MenuAction_End) {
		delete menu;
	}
}

public Action VoteLast(int client, int args) {
	if (IsVoteInProgress()) return Plugin_Handled;
	int lastRound = (roundCount-1 >= 0) ? roundCount-1 : 0;
	VoteConfirmation(client, lastRound);
	return Plugin_Handled;
}

public Action VoteConfirmation(int client, int args) {
	Menu menu = new Menu(Handle_VoteRound);
	voteRound = args;
	menu.SetTitle("Restore round %d?", args);
	menu.AddItem("yes", "Yes");
	menu.AddItem("no", "No");
	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, 20);
	return Plugin_Handled;
}

public int Handle_VoteMultipleRounds(Menu menu, MenuAction action, int param1,int param2) {
	if (action == MenuAction_Select) {
		char info[32];
		menu.GetItem(param2, info, sizeof(info));
		if(StrEqual(info, "...")) {
			if(voteRound < 5) VoteOther(param1, 0);
			else VoteOther(param1, voteRound-5);
		}
		else {
			PrintToChat(param1, "%s You selected round: %s", ChatPrefix1, info);
			VoteConfirmation(param1, StringToInt(info));
		}
	}
	else if (action == MenuAction_Cancel) {
		if(param2 == MenuCancel_ExitBack) {
			MainMenu(param1, 20);
		}
		else
			PrintToChat(param1, "%s Menu cancelled.", ChatPrefix2);
	}
	else if (action == MenuAction_End) {
		delete menu;
	}
}

public Action VoteOther(int client, int args) {
	if (IsVoteInProgress()) return;
	Menu menu = new Menu(Handle_VoteMultipleRounds);
	menu.SetTitle("Which round to restore?");
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	char roundString[8];
	char roundString2[16];
	voteRound = (args > 0) ? args-1 : 0;
	if(voteRound > 0) menu.AddItem("...", "Previous Rounds");
	for(int i = voteRound; i <= 30; i++) {
		Format(roundString, sizeof(roundString), "%d", i+1);
		Format(roundString2, sizeof(roundString2), "Round %s", roundString);
		menu.AddItem(roundString, roundString2);
	}
	menu.Display(client, 20);
}

public Action restoreRound(int round) {
	roundCount = round;
	char roundName[64];
	char prefix1[16] = "backup_round0";
	char prefix2[16] = "backup_round";
	char end[8] = ".txt";
	if(round<10)
		Format(roundName, sizeof(roundName), "%s%d%s", prefix1, round, end);
	else
		Format(roundName, sizeof(roundName), "%s%d%s", prefix2, round, end);
	PrintToChatAll("%s Restoring Round %d", ChatPrefix1, round);
	ServerCommand("mp_backup_restore_load_file %s", roundName);
	PrintToChatAll("%s Restored Round, have fun!", ChatPrefix1);
	return Plugin_Handled;
}
