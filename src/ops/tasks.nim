import std/[json, os]
import ../net/[client, adsgram]
import ../support/log

proc runTasks*(session: Session) =
  let (code, node) = session.callJson("GET", "/api/tasks")
  if code != 200 or node.kind != JArray:
    red("Task list could not be retrieved for this account")
    return
  var claimed = 0
  var pending = 0
  for task in node:
    if valueOf(task, "type") == "telegram":
      continue
    let taskId = valueOf(task, "id")
    if taskId.len == 0:
      continue
    let (done, _) = session.callJson("POST", "/api/tasks/complete",
      %*{"userId": session.userId, "taskId": taskId})
    if done == 200:
      inc claimed
    elif done == 400:
      discard
    else:
      inc pending
    sleep(1000)
  if claimed > 0:
    green("All available tasks completed for this account and " & $claimed & " rewards were claimed")
  elif pending > 0:
    yellow($pending & " account tasks could not be completed on this run")
  else:
    green("Every available account task was already completed")

proc runAdMissions*(session: Session, settings: JsonNode, language: string,
    isPremium: bool) =
  let missions = settings{"adTaskMissions"}
  if missions == nil or missions.kind != JArray or missions.len == 0:
    return
  let fallbackBlock = valueOf(settings, "adsgramTaskBlockId")
  var claimed = 0
  for mission in missions:
    let missionId = valueOf(mission, "id")
    if missionId.len == 0:
      continue
    let label = valueOf(mission, "label", "Ad mission")
    var (code, node) = session.callJson("POST", "/api/tasks/complete-ad-task",
      %*{"userId": session.userId, "taskId": missionId})
    if code != 200 or not boolOf(node, "success", false):
      if code != 400:
        discard session.callJson("POST", "/api/ads/track",
          %*{"userId": session.userId, "type": "task"})
        let blockId = valueOf(mission, "blockId", fallbackBlock)
        discard serveAd(session, blockId, language, isPremium)
        (code, node) = session.callJson("POST", "/api/tasks/complete-ad-task",
          %*{"userId": session.userId, "taskId": missionId})
    if code == 200 and boolOf(node, "success", false):
      inc claimed
      green("Ad mission " & label & " was completed for " & $intOf(node, "reward", intOf(mission, "reward", 0)) & " coins on this account")
  if claimed == 0:
    green("Every ad mission was already completed for this account")
