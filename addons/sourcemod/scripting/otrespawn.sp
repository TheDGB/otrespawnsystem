/*****************************************************************************
              Oppressive Territory Respawn System (4FuN Plugin)
******************************************************************************/

#include <sourcemod>
#include <morecolors>
#include <sdktools>
#include <tf2>
#include <tf2_stocks>

#pragma semicolon 1
#pragma newdecls required

#define MAX_BUTTONS 25
int g_LastButtons[MAXPLAYERS+1];
float g_fLastRespawnTime[MAXPLAYERS+1];
int g_iWinningTeam;

Handle g_hHudSync;
Handle g_hRespawnTimer[MAXPLAYERS + 1];

/////////////////////////////////////////////// Outro
ConVar g_cvEnable, g_cvLoser, g_cvDelay, g_cvWinner, g_cvHud, g_cvBlue, g_cvRed;

#define IN_ATTACK       (1 << 0)
#define IN_JUMP         (1 << 1)
#define IN_DUCK         (1 << 2)
#define IN_FORWARD      (1 << 3)
#define IN_BACK         (1 << 4)
#define IN_USE          (1 << 5)
#define IN_CANCEL       (1 << 6)
#define IN_LEFT         (1 << 7)
#define IN_RIGHT        (1 << 8)
#define IN_MOVELEFT     (1 << 9)
#define IN_MOVERIGHT    (1 << 10)
#define IN_ATTACK2      (1 << 11)
#define IN_RUN          (1 << 12)
#define IN_RELOAD       (1 << 13)
#define IN_ALT1         (1 << 14)
#define IN_ALT2         (1 << 15)
#define IN_SCORE        (1 << 16)
#define IN_SPEED        (1 << 17)
#define IN_WALK         (1 << 18)
#define IN_ZOOM         (1 << 19)
#define IN_WEAPON1      (1 << 20)
#define IN_WEAPON2      (1 << 21)
#define IN_BULLRUSH     (1 << 22)
#define IN_GRENADE1     (1 << 23)
#define IN_GRENADE2     (1 << 24)

/////////////////////////////////////////////// Plugin Info

public Plugin myinfo = {
    name        = "Oppressive Territory Respawn",
    author      = "DGB",
    description = "Key pressing event for Respawn.",
    version     = "1.25",
    url         = "optr.me"
};

/////////////////////////////////////////////// Default settings

public void OnPluginStart()
{
    g_hHudSync = CreateHudSynchronizer();
    HookEvent("player_death", Event_PlayerDeath);
    HookEvent("teamplay_round_win", Event_RoundWin);
    HookEvent("teamplay_round_start", Event_RoundStart);
    
    g_cvEnable = CreateConVar("sm_otrespawn_enable", "1", "Activates the fast respawn system", 0, true, 0.0, true, 1.0);
    g_cvLoser = CreateConVar("sm_otrespawn_loser", "1", "Blocks fast key respawn for the losing team", 0, true, 0.0, true, 1.0);
    g_cvDelay = CreateConVar("sm_otrespawn_delay", "8.0", "Cooldown for quick key respawn if spammed.", 0, true, 0.0);
    g_cvWinner = CreateConVar("sm_otrespawn_winner", "1", "Blocks fast key respawn for the winning team", 0, true, 0.0, true, 1.0);
    g_cvHud = CreateConVar("sm_otrespawn_hud", "1", "Toggles the respawn HUD on/off", 0, true, 0.0, true, 1.0);
    g_cvBlue = CreateConVar("sm_otrespawn_blue", "1", "Enable/disable the respawn plugin for Blue team", 0, true, 0.0, true, 1.0);
    g_cvRed = CreateConVar("sm_otrespawn_red", "1", "Enable/disable the respawn plugin for Red team", 0, true, 0.0, true, 1.0);
    
    AutoExecConfig(true, "ot_respawn");
}

public void OnClientDisconnect_Post(int client)
{
    g_LastButtons[client] = 0;
    g_fLastRespawnTime[client] = 0.0;
    ClearTimer(client);
}

/////////////////////////////////////////////// Revive Button
public void OnButtonPress(int client, int button)
{
    if (button == IN_RELOAD && IsValidClient(client) && !IsPlayerAlive(client) && GetClientTeam(client) > 1)
    {
        int clientTeam = GetClientTeam(client);
        float gameTime = GetGameTime();
        
        if((clientTeam == 2 && !g_cvRed.BoolValue) || (clientTeam == 3 && !g_cvBlue.BoolValue)) {
            return;
        }
        
        if(g_cvLoser.BoolValue && g_iWinningTeam != 0 && clientTeam != g_iWinningTeam)
        {
            return;
        }
        
        if(g_cvWinner.BoolValue && g_iWinningTeam != 0 && clientTeam == g_iWinningTeam)
        {
            return;
        }
        
        float delay = g_cvDelay.FloatValue;
        if(delay > 0 && gameTime - g_fLastRespawnTime[client] < delay)
        {
            return;
        }
        
        TF2_RespawnPlayer(client);
        g_fLastRespawnTime[client] = gameTime;
        ClearTimer(client);
    }
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
    if(g_cvEnable.BoolValue)
    {
        for(int i = 0; i < MAX_BUTTONS; i++)
        {
            int button = (1 << i);
            
            if((buttons & button) && !(g_LastButtons[client] & button))
            {
                OnButtonPress(client, button);
            }
        }
    }
    
    g_LastButtons[client] = buttons;
    return Plugin_Continue;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    
    if(g_cvEnable.BoolValue && IsValidClient(client) && GetClientTeam(client) > 1)
    {
        ClearTimer(client);
        g_hRespawnTimer[client] = CreateTimer(0.1, Timer_ShowHud, GetClientSerial(client), TIMER_REPEAT);
    }
}

/////////////////////////////////////////////// User Hud
public Action Timer_ShowHud(Handle timer, any serial)
{
    int client = GetClientFromSerial(serial);
    
    if(IsValidClient(client) && !IsPlayerAlive(client) && GetClientTeam(client) > 1)
    {
        int clientTeam = GetClientTeam(client);
        
        if((clientTeam == 2 && !g_cvRed.BoolValue) || (clientTeam == 3 && !g_cvBlue.BoolValue)) {
            return Plugin_Continue;
        }
        
        if(g_cvHud.BoolValue)
        {
            SetHudTextParams(-1.0, 0.8, 1.1, 255, 255, 255, 255);
            ShowSyncHudText(client, g_hHudSync, "You are dead\nPress 'Reload' or '+reload' to revive quickly");
        }
        return Plugin_Continue;
    }
    
    if(g_hRespawnTimer[client] == timer)
    {
        g_hRespawnTimer[client] = null;
    }
    
    return Plugin_Stop;
}

public void Event_RoundWin(Event event, const char[] name, bool dontBroadcast)
{
    g_iWinningTeam = event.GetInt("team");
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_iWinningTeam = 0;
}

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

/////////////////////////////////////////////// Clearing Hud
void ClearTimer(int client)
{
    if(g_hRespawnTimer[client] != null)
    {
        KillTimer(g_hRespawnTimer[client]);
        g_hRespawnTimer[client] = null;
    }
}