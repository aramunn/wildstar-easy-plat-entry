require "Window"

local EasyPlatEntry = {}

-------------------------------------------------------------------------------
--constants
-------------------------------------------------------------------------------
--table of sets of addons we want to hook into
--  addon: name of the addon
--  [init]: set to true if method is called on load
--  method: method after which we'll add our window events
--  [container]: name of variable containing class we need
--  base: name of the variable containing the base window
--  [path]: path to the target cash window
--  [post]: function to call after setting a new amount
--  [link]: info for window to link to
--    name: name of set we want
--    levels: number of levels to go up to find it
local sets = {
  ahSellBuyout = {
    addon = "MarketplaceAuction",
    method = "Initialize",
    base = "wndMain",
    path = "CreateBuyoutInputBox",
    post = "OnCreateBuyoutInputBoxChanged",
    link = {
      name = "ahSellBid",
      levels = 2,
    },
  },
  ahSellBid = {
    addon = "MarketplaceAuction",
    method = "Initialize",
    base = "wndMain",
    path = "CreateBidInputBox",
    post = "OnCreateBidInputBoxChanged",
    link = {
      name = "ahSellBuyout",
      levels = 2,
    },
  },
  {
    addon = "MarketplaceAuction",
    method = "Initialize",
    base = "wndMain",
    path = "BottomBidPrice",
    post = "OnBidPriceAmountChanged",
  },
  -- {
    -- addon = "MarketplaceAuction",
    -- method = "Initialize",
    -- base = "wndMain",
    -- path = "FilterOptionsBuyoutCash",
    -- post = "OnFilterEditBoxChanged", --wrong wndHandler?
  -- },
  {
    addon = "MarketplaceCommodity",
    method = "OnListInputPriceMouseDown",
    post = "OnListInputPriceAmountChanged",
  },
  {
    addon = "MarketplaceCREDD",
    method = "Initialize",
    base = "tWindowMap.Main",
    path = "ActLaterPrice",
    post = "OnCashInputChanged",
  },
  {
    addon = "GuildBank",
    method = "Initialize",
    base = "tWndRefs.wndMain",
    path = "GuildCashInteractEditCashWindow",
    post = "OnGuildCashInteractEditCashWindow",
  },
  -- {
    -- addon = "GuildBank",
    -- method = "GuildInitialize",
    -- base = "tWndRefs.wndMain",
    -- path = "PermissionsMoneyCashWindow",
    -- post = "OnPermissionsMoneyCashWindow",
  -- },
  -- {
    -- addon = "GuildBank",
    -- method = "GuildInitialize",
    -- base = "tWndRefs.wndMain",
    -- path = "PermissionsRepairCashWindow",
    -- post = "OnPermissionsRepairCashWindow",
  -- },
  {
    addon = "Mail",
    method = "ComposeMail",
    container = "luaComposeMail",
    base = "wndMain",
    path = "CashWindow",
    post = "OnCashAmountChanged",
  },
  {
    addon = "Trading",
    init = true,
    method = "OnDocumentReady",
    base = "wndTradeForm",
    path = "YourCash",
    post = "OnCashAmountChanged",
  },
}

--what to call the methods we add to other addons
local eventFunctionPrefix = "EasyPlatEntryEvent"

-------------------------------------------------------------------------------
--using a cash amount, build a string in proper format
-------------------------------------------------------------------------------
local function convertAmountToString(amt)
  local curAmtStr = ""
  local denominations = { "c", "s", "g", "p" }
  for idx, denomination in ipairs(denominations) do
    --extract denomination value from amount
    local value = amt
    if idx < #denominations then value = value % 100 end
    --add value to string if not zero
    if value > 0 then
      --add space if more than one value in this string
      if curAmtStr ~= "" then
        curAmtStr = " "..curAmtStr
      end
      --add value and denomination character to front of string
      curAmtStr = value..denomination..curAmtStr
    end
    --adjust amount
    amt = (amt - value) / 100
  end
  return curAmtStr
end

-------------------------------------------------------------------------------
--parse a (hopefully) formatted string
-------------------------------------------------------------------------------
local function convertStringToAmount(str)
  local strToParse = string.lower(str)
  local total = 0
  local strToCompare = ""
  local denominations = { "p", "g", "s", "c" }
  for idx, denomination in ipairs(denominations) do
    --get a number followed by a denomination character
    local value, remaining = string.match(strToParse, "^%s*(%d+)%s*"..denomination.."(.*)$")
    if value ~= nil then
      --add appropriate amount to total
      total = total + math.floor(tonumber(value) * math.pow(100, #denominations - idx))
      --update our strings
      strToParse = remaining
      strToCompare = strToCompare..value..denomination
    end
  end
  --check if the string we made matches the user's input
  local matches = strToCompare == string.lower(string.gsub(str, '%s', ""))
  return matches, total
end

-------------------------------------------------------------------------------
--handle linked windows
-------------------------------------------------------------------------------
function EasyPlatEntry:HandleLink(data, addon, window, amount, tab)
  --don't do anything if we already handled this link
  if self.linksHandled[data.name] then return end
  --grab set data for window we want to link to
  local set = sets[data.name]
  --go up from current window then find our target
  local link = window
  for i=1,data.levels do link = link:GetParent() end
  link = link:FindChild(set.path)
  --quit if we didn't find target window
  if not link then return end
  --set handled flag for this link
  self.linksHandled[data.name] = true
  --update linked window with relative value
  if data.percent then
    local amount = math.floor(amount*data.percent + .5) --round
    self:UpdateAmount(link, set, amount)
  end
  --pretend we clicked the linked window if tab was used
  if tab then self:MouseButtonDownEvent(link, set) end
end

-------------------------------------------------------------------------------
--update cash window
-------------------------------------------------------------------------------
function EasyPlatEntry:UpdateAmount(cashWindow, set, amount, tab)
  Print("updating to "..amount)
  --set the new amount
  cashWindow:SetAmount(amount)
  --call post method if needed
  if set and set.post then
    local addon = Apollo.GetAddon(set.addon)
    if set.container then addon = addon[set.container] end
    addon[set.post](addon, cashWindow, cashWindow)
    --handle links
    if set.link then self:HandleLink(set.link, addon, cashWindow, amount, tab) end
  end
end

-------------------------------------------------------------------------------
--create an error display
-------------------------------------------------------------------------------
function EasyPlatEntry:UpdateError(cashWindow, editBox)
  --clean up old errors if they exist
  self:OnPixieTimer()
  --decide where to put the error
  local errorOffsets
  if self.wndMain:IsVisible() then
    errorWindow = self.wndMain
    errorOffsets = {5,0,-5,2}
    editBox:SetFocus()
  else
    errorWindow = cashWindow
    errorOffsets = {0,-5,0,5}
  end
  --add the error display and set a timer
  errorPixie = errorWindow:AddPixie({
    strSprite = "CRB_NameplateSprites:sprNp_VulnerableBarFlash",
    loc = { fPoints = {0,0,1,1}, nOffsets = errorOffsets },
    cr = "AddonError",
  })
  self.timer = ApolloTimer.Create(0.5, false, "OnPixieTimer", self)
end

-------------------------------------------------------------------------------
--read window status and update as needed
-------------------------------------------------------------------------------
function EasyPlatEntry:UpdateWindow(tab)
  --reset flags
  self.linksHandled = {}
  --ensure our window is up
  if not self.wndMain or not self.wndMain:IsValid() then return end
  --grab the cash window we're attached to
  local cashWindow = self.wndMain:GetParent()
  --attempt to get value from string
  local editBox = self.wndMain:FindChild("EditBox")
  local good, amount = convertStringToAmount(editBox:GetText())
  if good then
    local set = editBox:GetData()
    self:Destroy()
    self:UpdateAmount(cashWindow, set, amount, tab)
  else
    self:UpdateError(cashWindow, editBox)
  end
end

-------------------------------------------------------------------------------
--timer functions
-------------------------------------------------------------------------------
function EasyPlatEntry:OnPixieTimer()
  if errorWindow and errorWindow:IsValid() then
    errorWindow:DestroyPixie(errorPixie)
  end
  errorWindow = nil
end

-------------------------------------------------------------------------------
--when user hits escape in the edit box
-------------------------------------------------------------------------------
function EasyPlatEntry:OnEditBoxEscape()
  self:Destroy()
end

-------------------------------------------------------------------------------
--when user clicks off of the pop-up window
-------------------------------------------------------------------------------
function EasyPlatEntry:OnWindowClosed()
  self:UpdateWindow()
  self:Destroy()
end

-------------------------------------------------------------------------------
--when user hits enter in the edit box
-------------------------------------------------------------------------------
function EasyPlatEntry:OnEditBoxReturn(wndHandler, wndControl, strText)
  self:UpdateWindow()
end

-------------------------------------------------------------------------------
--when user hits tab in the edit box
-------------------------------------------------------------------------------
function EasyPlatEntry:OnEditBoxTab(wndHandler, wndControl, strText)
  self:UpdateWindow(true)
end

-------------------------------------------------------------------------------
--destroy our main window
-------------------------------------------------------------------------------
function EasyPlatEntry:Destroy()
  if self.wndMain and self.wndMain:IsValid() then
    self.wndMain:Destroy()
    self.wndMain = nil
  end
end

-------------------------------------------------------------------------------
--event called by hooked cash window
-------------------------------------------------------------------------------
function EasyPlatEntry:MouseButtonDownEvent(cashWindow, set)
  --update and remove a previous window
  self:UpdateWindow()
  self:Destroy()
  --load our pop-up window
  self.wndMain = Apollo.LoadForm(self.xmlDoc, "EasyPlatEntryForm", cashWindow, self)
  local editBox = self.wndMain:FindChild("EditBox")
  --add data to edit box for later
  editBox:SetData(set)
  --set current value and focus on edit box
  local amount = cashWindow:GetAmount()
  editBox:SetText(convertAmountToString(amount))
  editBox:SetFocus()
end

-------------------------------------------------------------------------------
--add our event to target window
-------------------------------------------------------------------------------
function EasyPlatEntry:AddWindowEvent(set, addon, window)
    local addon = addon
    --check if container present
    if set.container then
      addon = addon[set.container]
      if addon["EasyPlatEntryFlag"] then return end
      addon["EasyPlatEntryFlag"] = true
    end
    if set.path then
      --we need to add an event handler to a window and the addon
      local eventFunctionName = eventFunctionPrefix
      if set.post then eventFunctionName = eventFunctionName.."With"..set.post end
      local wndBase = addon
      for base in string.gmatch(set.base, '%w+') do
        wndBase = wndBase[base]
      end
      local cashWindow = wndBase:FindChild(set.path)
      if not cashWindow then return end
      cashWindow:AddEventHandler("MouseButtonDown", eventFunctionName)
      addon[eventFunctionName] = function(wndHandler, wndControl) self:MouseButtonDownEvent(wndControl, set) end
    else
      --we only need to add to the existing handler
      self:MouseButtonDownEvent(window, set)
    end
end

-------------------------------------------------------------------------------
--set processing
-------------------------------------------------------------------------------
function EasyPlatEntry:ProcessSet(set, addon)
  if set.init and addon[set.base] then
    self:AddWindowEvent(set, addon)
  else
    --add extra code to a function in addon
    local method = addon[set.method]
    addon[set.method] = function (wndHandler, wndControl, ...)
      method(wndHandler, wndControl, ...)
      self:AddWindowEvent(set, addon, wndControl)
    end
  end
end

function EasyPlatEntry:ProcessSets()
  --iterate through sets
  for idx, set in pairs(sets) do
    --ensure addon is running
    local addon = Apollo.GetAddon(set.addon)
    if addon then
      self:ProcessSet(set, addon)
    end
  end
end

-------------------------------------------------------------------------------
--options
-------------------------------------------------------------------------------
function EasyPlatEntry:LoadOptionsWindow()
  if not self.wndOptions:IsShown() then self.wndOptions:Show(true) end
end

function EasyPlatEntry:OnOK()
  Print("ok pressed")
  self.wndOptions:Show(false)
  for key, value in pairs(self.tSave) do
    Print("["..tostring(key).."] = "..tostring(value))
    for key, value in pairs(value) do
      Print("["..tostring(key).."] = "..tostring(value))
    end
  end
end

function EasyPlatEntry:OnCancel()
  Print("cancel pressed")
  self.wndOptions:Show(false)
end

function EasyPlatEntry:OnSave(eLevel)
  if eLevel ~= GameLib.CodeEnumAddonSaveLevel.Character then return nil end
  return self.tSave
end

function EasyPlatEntry:OnRestore(eLevel, tSave)
  self:LoadDefaultSettings()
  --load user settings, removing old ones
  -- for key, value in pairs(tSave) do
    -- if self.tSave[key] then self.tSave[key] = value end
  -- end
  self:ProcessSettings()
end

function EasyPlatEntry:LoadDefaultSettings()
  self.tSave = {
    ahBidBuyoutLink = {
      enable = true,
      percent = 0.75,
    },
  }
end

function EasyPlatEntry:ProcessSettings()
  --AH bid/buyout price link
  local link = self.tSave.ahBidBuyoutLink
  local percent = (link.enable and link.percent) or nil
  sets.ahSellBuyout.link.percent = percent
  sets.ahSellBid.link.percent = percent and (1/percent)
end

function EasyPlatEntry:OnInterfaceMenuLoaded()
  local tData = {"InterfaceMenu", "", "CRB_CurrencySprites:sprCashPlatinum"}
  Event_FireGenericEvent("InterfaceMenuList_NewAddOn", "EasyPlatEntry", tData)
end

-------------------------------------------------------------------------------
--required addon functions
-------------------------------------------------------------------------------
function EasyPlatEntry:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

function EasyPlatEntry:Init()
  Apollo.RegisterAddon(self)
end

function EasyPlatEntry:OnLoad()
  self.xmlDoc = XmlDoc.CreateFromFile("EasyPlatEntry.xml")
  self.xmlDoc:RegisterCallback("OnDocumentReady", self)
end

function EasyPlatEntry:OnDocumentReady()
  --make sure xml is loaded
  if self.xmlDoc == nil then return end
  if not self.xmlDoc:IsLoaded() then return end
  --process everything
  self:ProcessSets()
  --register what we need
  Apollo.RegisterEventHandler("InterfaceMenuListHasLoaded", "OnInterfaceMenuLoaded", self)
  Apollo.RegisterEventHandler("InterfaceMenu", "LoadOptionsWindow", self)
  Apollo.RegisterSlashCommand("easyplatentry", "LoadOptionsWindow", self)
  Apollo.RegisterSlashCommand("epe", "LoadOptionsWindow", self)
  --load our options window (hidden)
  self.wndOptions = Apollo.LoadForm(self.xmlDoc, "EasyPlatEntryOptions", "InWorldHudStratum", self)
  self:LoadDefaultSettings()
end

-------------------------------------------------------------------------------
--set up addon
-------------------------------------------------------------------------------
local errorPixie, errorWindow
local EasyPlatEntryInst = EasyPlatEntry:new()
EasyPlatEntryInst:Init()
