#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>
#include <nativevotes_rework>
#include <boss_flow>
#include <colors>


public Plugin myinfo =
{
    name        = "BossFlowVoteBoss",
    author      = "TouchMe",
    description = "The plugin allows you to vote for the position of bosses",
    version     = "build_0001",
    url         = "https://github.com/TouchMe-Inc/l4d2_boss_flow"
}


#define TRANSLATIONS            "bf_voteboss.phrases"

#define TEAM_SPECTATE           1

#define VOTE_TIME               15


int
    g_iTargetTankFlow = 0,
    g_iTargetWitchFlow = 0
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
    if (GetEngineVersion() != Engine_Left4Dead2)
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
 * When a player wants to find out whos becoming tank,
 * output to them.
 */
Action Cmd_VoteBoss(int iClient, int iArgs)
{
    if (iArgs != 2)
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "INVALID_ARGS", iClient);
        return Plugin_Handled;
    }

    if (IsClientSpectator(iClient))
    {
        CPrintToChat(iClient, "%T%T", "TAG", iClient, "INVALID_TEAM", iClient);
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

    char szTankFlow[4]; GetCmdArg(1, szTankFlow, sizeof(szTankFlow));
    char szWitchFlow[4]; GetCmdArg(2, szWitchFlow, sizeof(szWitchFlow));

    int iTankFlow = (szTankFlow[0] == '-' || !IsBossSpawnAllowed(Boss_Tank)) ? -1 : 0;
    int iWitchFlow = (szWitchFlow[0] == '-' || !IsBossSpawnAllowed(Boss_Witch)) ? -1 : 0;

    char szErrorMessage[192];
    Handle hErrorMessages = CreateArray(ByteCountToCells(sizeof(szErrorMessage)));

    if (iTankFlow != -1 && !IsMapWithStaticBossSpawn(Boss_Tank))
    {
        iTankFlow = StringToInt(szTankFlow);

        if (iTankFlow)
        {
            int iIsAvaibleTankFlow = IsAvaibleBossFlow(Boss_Tank, iTankFlow);

            if (iIsAvaibleTankFlow == -2)
            {
                FormatEx(szErrorMessage, sizeof(szErrorMessage), "%T", "INVALID_TANK_PERCENT", iClient);
                PushArrayString(hErrorMessages, szErrorMessage);
            }

            else if (iIsAvaibleTankFlow != 1)
            {
                FormatEx(szErrorMessage, sizeof(szErrorMessage), "%T", "INVALID_TANK_FLOW", iClient, iTankFlow);
                PushArrayString(hErrorMessages, szErrorMessage);
            }
        }
    }

    if (iWitchFlow != -1 && !IsMapWithStaticBossSpawn(Boss_Witch))
    {
        iWitchFlow = StringToInt(szWitchFlow);

        if (iWitchFlow)
        {
            int iIsAvaibleWitchFlow = IsAvaibleBossFlow(Boss_Witch, iWitchFlow);

            if (iIsAvaibleWitchFlow == -2)
            {
                FormatEx(szErrorMessage, sizeof(szErrorMessage), "%T", "INVALID_WITCH_PERCENT", iClient);
                PushArrayString(hErrorMessages, szErrorMessage);
            }

            else if (iIsAvaibleWitchFlow != 1)
            {
                FormatEx(szErrorMessage, sizeof(szErrorMessage), "%T", "INVALID_WITCH_FLOW", iClient, iWitchFlow);
                PushArrayString(hErrorMessages, szErrorMessage);
            }
        }
    }

    if (iTankFlow == iWitchFlow && iTankFlow > 0 && iWitchFlow > 0)
    {
        FormatEx(szErrorMessage, sizeof(szErrorMessage), "%T", "INVALID_BOSS_POINT", iClient);
        PushArrayString(hErrorMessages, szErrorMessage);
    }

    int iArraySize = GetArraySize(hErrorMessages);

    if (iArraySize)
    {
        CPrintToChat(iClient, "%T%T", "BRACKET_START", iClient, "TAG", iClient);

        for (int iIndex = 0; iIndex < iArraySize; iIndex ++)
        {
            GetArrayString(hErrorMessages, iIndex, szErrorMessage, sizeof(szErrorMessage));
            CPrintToChat(iClient, "%T%s", (iIndex + 1) == iArraySize ? "BRACKET_END" : "BRACKET_MIDDLE", iClient, szErrorMessage);
        }

        CloseHandle(hErrorMessages);
        return Plugin_Handled;
    }

    CloseHandle(hErrorMessages);

    RunVoteBoss(iClient, iTankFlow, iWitchFlow);

    return Plugin_Handled;
}

void RunVoteBoss(int iClient, int iTankFlow, int iWitchFlow)
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

    g_iTargetTankFlow = iTankFlow;
    g_iTargetWitchFlow = iWitchFlow;

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

            if (g_iTargetTankFlow == -1) {
                FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "IGNORED", iParam1);
            } else if (IsMapWithStaticBossSpawn(Boss_Tank)) {
                FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "STATIC", iParam1);
            } else if (g_iTargetTankFlow == 0) {
                FormatEx(sTankPercent, sizeof(sTankPercent), "%T", "DISABLE", iParam1);
            } else {
                FormatEx(sTankPercent, sizeof(sTankPercent), "%d", g_iTargetTankFlow);
            }

            if (g_iTargetWitchFlow == -1) {
                FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "IGNORED", iParam1);
            } else if (IsMapWithStaticBossSpawn(Boss_Witch)) {
                FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "STATIC", iParam1);
            } else if (g_iTargetWitchFlow == 0) {
                FormatEx(sWitchPercent, sizeof(sWitchPercent), "%T", "DISABLE", iParam1);
            } else {
                FormatEx(sWitchPercent, sizeof(sWitchPercent), "%d", g_iTargetWitchFlow);
            }

            FormatEx(sVoteDisplayMessage, sizeof(sVoteDisplayMessage), "%T", "VOTE_TITLE", iParam1, sTankPercent, sWitchPercent);

            hVote.SetDetails(sVoteDisplayMessage);

            return Plugin_Changed;
        }

        case VoteAction_Cancel: hVote.DisplayFail();

        case VoteAction_Finish:
        {
            if (iParam1 == NATIVEVOTES_VOTE_NO || IsRoundStarted())
            {
                hVote.DisplayFail();

                return Plugin_Continue;
            }

            if (g_iTargetTankFlow != -1 && !IsMapWithStaticBossSpawn(Boss_Tank)) {
                SetBossFlow(Boss_Tank, g_iTargetTankFlow);
            }

            if (g_iTargetWitchFlow != -1 && !IsMapWithStaticBossSpawn(Boss_Witch)) {
                SetBossFlow(Boss_Witch, g_iTargetWitchFlow);
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
