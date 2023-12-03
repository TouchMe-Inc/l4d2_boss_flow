#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>
#include <nativevotes_rework>
#include <boss_flow>
#include <colors>


public Plugin myinfo =
{
	name = "BossFlowVote",
	author = "TouchMe",
	description = "The plugin allows you to vote for the position of bosses",
	version = "build0000",
	url = "https://github.com/TouchMe-Inc/l4d2_boss_flow"
}


#define MIN_FLOW 1
#define MAX_FLOW 100

#define TRANSLATIONS            "bf_voteboss.phrases"

#define TEAM_SPECTATE           1

#define VOTE_TIME               15


int
	g_iTankPercent = 0,
	g_iWitchPercent = 0
;

bool g_bRoundIsLive = false;


/**
 * Called before OnPluginStart.
 *
 * @param myself            Handle to the plugin.
 * @param late              Whether or not the plugin was loaded "late" (after map load).
 * @param error             Error message buffer in case load failed.
 * @param err_max           Maximum number of characters for error message buffer.
 * @return                  APLRes_Success | APLRes_SilentFailure.
 */
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	EngineVersion engine = GetEngineVersion();

	if (engine != Engine_Left4Dead2)
	{
		strcopy(error, err_max, "Plugin only supports Left 4 Dead 2.");
		return APLRes_SilentFailure;
	}

	return APLRes_Success;
}

public void OnPluginStart()
{
	// Load translations.
	LoadTranslations(TRANSLATIONS);

	// Event hooks.
	HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_left_start_area", Event_LeftStartArea, EventHookMode_PostNoCopy);
	HookEvent("round_end", Event_RoundEnd, EventHookMode_PostNoCopy);

	RegConsoleCmd("sm_voteboss", Cmd_VoteBoss);
}

/**
 * Round start event.
 */
void Event_RoundStart(Event event, const char[] sName, bool bDontBroadcast) {
	g_bRoundIsLive = false;
}

/**
 * Round start event.
 */
void Event_LeftStartArea(Event event, const char[] sName, bool bDontBroadcast) {
	g_bRoundIsLive = true;
}

/**
 * Round end event.
 */
void Event_RoundEnd(Event event, const char[] sName, bool bDontBroadcast) {
	g_bRoundIsLive = false;
}

/**
 * When a player wants to find out whos becoming tank,
 * output to them.
 */
Action Cmd_VoteBoss(int iClient, int iArgs)
{
	if (IsClientSpectator(iClient))
	{
		CPrintToChat(iClient, "%T%T", "TAG", iClient, "INVALID_TEAM", iClient);
		return Plugin_Handled;
	}

	if (iArgs != 2)
	{
		CPrintToChat(iClient, "%T%T", "TAG", iClient, "INVALID_ARGS", iClient);
		return Plugin_Handled;
	}

	if (InSecondHalfOfRound())
	{
		CPrintToChat(iClient, "%T%T", "TAG", iClient, "INVALID_ROUND", iClient);
		return Plugin_Handled;
	}

	if (IsRoundStarted())
	{
		CPrintToChat(iClient, "%T%T", "TAG", iClient, "ROUND_STARTED", iClient);
		return Plugin_Handled;
	}

	char sTankPercent[4]; GetCmdArg(1, sTankPercent, sizeof(sTankPercent));
	char sWitchPercent[4]; GetCmdArg(2, sWitchPercent, sizeof(sWitchPercent));

	int iTankPercent = sTankPercent[0] == '-' ? -1 : 0;
	int iWitchPercent = sWitchPercent[0] == '-' ? -1 : 0;

	char sErrorMessage[192];

	Handle hErrorMessages = CreateArray(ByteCountToCells(sizeof(sErrorMessage)));

	if (iTankPercent != -1 && !IsStaticTankMap())
	{
		iTankPercent = StringToInt(sTankPercent);

		if (iTankPercent)
		{
			if (!IsValidPercent(iTankPercent))
			{
				FormatEx(sErrorMessage, sizeof(sErrorMessage), "%T", "INVALID_TANK_PERCENT", iClient);
				PushArrayString(hErrorMessages, sErrorMessage);
			}

			else if (!IsValidTankFlowPercent(iTankPercent))
			{
				FormatEx(sErrorMessage, sizeof(sErrorMessage), "%T", "INVALID_TANK_FLOW", iClient, iTankPercent);
				PushArrayString(hErrorMessages, sErrorMessage);
			}
		}
	}

	if (iWitchPercent != -1 && !IsStaticWitchMap())
	{
		iWitchPercent = StringToInt(sWitchPercent);

		if (iWitchPercent)
		{
			if (!IsValidPercent(iWitchPercent))
			{
				FormatEx(sErrorMessage, sizeof(sErrorMessage), "%T", "INVALID_WITCH_PERCENT", iClient);
				PushArrayString(hErrorMessages, sErrorMessage);
			}

			else if (!IsValidWitchFlowPercent(iWitchPercent))
			{
				FormatEx(sErrorMessage, sizeof(sErrorMessage), "%T", "INVALID_WITCH_FLOW", iClient, iWitchPercent);
				PushArrayString(hErrorMessages, sErrorMessage);
			}
		}
	}

	if (iTankPercent == iWitchPercent && iTankPercent > 0 && iWitchPercent > 0)
	{
		FormatEx(sErrorMessage, sizeof(sErrorMessage), "%T", "INVALID_BOSS_POINT", iClient);
		PushArrayString(hErrorMessages, sErrorMessage);
	}

	int iArraySize = GetArraySize(hErrorMessages);

	if (iArraySize)
	{
		char sBracketStart[16]; FormatEx(sBracketStart, sizeof(sBracketStart), "%T", "BRACKET_START", iClient);
		char sBracketMiddle[16]; FormatEx(sBracketMiddle, sizeof(sBracketMiddle), "%T", "BRACKET_MIDDLE", iClient);
		char sBracketEnd[16]; FormatEx(sBracketEnd, sizeof(sBracketEnd), "%T", "BRACKET_END", iClient);

		CPrintToChat(iClient, "%s%T", sBracketStart, "TAG", iClient);

		for (int iIndex = 0; iIndex < iArraySize; iIndex ++)
		{
			GetArrayString(hErrorMessages, iIndex, sErrorMessage, sizeof(sErrorMessage));
			CPrintToChat(iClient, "%s%s", (iIndex + 1) == iArraySize ? sBracketEnd : sBracketMiddle, sErrorMessage);
		}

		CloseHandle(hErrorMessages);
		return Plugin_Handled;
	}

	CloseHandle(hErrorMessages);

	RunVoteBoss(iClient, iTankPercent, iWitchPercent);

	return Plugin_Handled;
}

void RunVoteBoss(int iClient, int iTankPercent, int iWitchPercent)
{
	if (!NativeVotes_IsNewVoteAllowed())
	{
		CPrintToChat(iClient, "%T%T", "TAG", iClient, "VOTE_COULDOWN", iClient, NativeVotes_CheckVoteDelay());
		return;
	}

	int iTotalPlayers;
	int[] iPlayers = new int[MaxClients];

	for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
	{
		if (!IsClientInGame(iPlayer) || IsFakeClient(iPlayer) || IsClientSpectator(iPlayer)) {
			continue;
		}

		iPlayers[iTotalPlayers++] = iPlayer;
	}

	g_iTankPercent = iTankPercent;
	g_iWitchPercent = iWitchPercent;

	NativeVote hVote = new NativeVote(HandlerVoteBoss, NativeVotesType_Custom_YesNo);
	hVote.Initiator = iClient;

	hVote.DisplayVote(iPlayers, iTotalPlayers, VOTE_TIME);
}

/**
 * Called when a vote action is completed.
 *
 * @param hVote             The vote being acted upon.
 * @param tAction           The action of the vote.
 * @param iParam1           First action parameter.
 * @param iParam2           Second action parameter.
 */
Action HandlerVoteBoss(NativeVote hVote, VoteAction tAction, int iParam1, int iParam2)
{
	switch (tAction)
	{
		case VoteAction_Display:
		{
			char sVoteDisplayMessage[128];
			char sTankPercent[32], sWitchPercent[32];

			if (g_iTankPercent == -1) {
				FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "IGNORED", iParam1);
			} else if (IsStaticTankMap()) {
				FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "STATIC", iParam1);
			} else if (g_iTankPercent == 0) {
				FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "DISABLE", iParam1);
			} else {
				FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "PERCENT", iParam1, g_iTankPercent);
			}

			if (g_iWitchPercent == -1) {
				FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "IGNORED", iParam1);
			} else if (IsStaticWitchMap()) {
				FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "STATIC", iParam1);
			} else if (g_iWitchPercent == 0) {
				FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "DISABLE", iParam1);
			} else {
				FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "PERCENT", iParam1, g_iWitchPercent);
			}

			FormatEx(sVoteDisplayMessage, sizeof(sVoteDisplayMessage), "%T", "VOTE_TITLE", iParam1, sTankPercent, sWitchPercent);

			hVote.SetDetails(sVoteDisplayMessage);

			return Plugin_Changed;
		}

		case VoteAction_Cancel: {
			hVote.DisplayFail();
		}

		case VoteAction_Finish:
		{
			if (iParam1 == NATIVEVOTES_VOTE_NO || IsRoundStarted())
			{
				hVote.DisplayFail();

				return Plugin_Continue;
			}

			if (g_iTankPercent != -1 && !IsStaticWitchMap()) {
				SetTankFlowPercent(g_iTankPercent);
			}

			if (g_iWitchPercent != -1 && !IsStaticWitchMap()) {
				SetWitchFlowPercent(g_iWitchPercent);
			}

			hVote.DisplayPass();
		}

		case VoteAction_End: hVote.Close();
	}

	return Plugin_Continue;
}

/**
 *
 */
bool IsRoundStarted() {
	return g_bRoundIsLive;
}

/**
 *
 */
bool IsValidPercent(int iPercent) {
	return iPercent >= MIN_FLOW && iPercent <= MAX_FLOW;
}

/**
 * Checks if the current round is the second.
 *
 * @return                  Returns true if is second round, otherwise false.
 */
bool InSecondHalfOfRound() {
	return view_as<bool>(GameRules_GetProp("m_bInSecondHalfOfRound"));
}

/**
 *
 */
bool IsClientSpectator(int iClient) {
	return (GetClientTeam(iClient) == TEAM_SPECTATE);
}
