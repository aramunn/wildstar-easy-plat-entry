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
--  [tab]: settings for tab support
--    [link]: info for window to link to
--      name: name of set we want
--      levels: number of levels to go up to find it
local sets = {
  ahSellBuyout = {
    addon = "MarketplaceAuction",
    method = "Initialize",
    base = "wndMain",
    path = "CreateBuyoutInputBox",
    post = "OnCreateBuyoutInputBoxChanged",
  },
  ahSellBid = {
    addon = "MarketplaceAuction",
    method = "Initialize",
    base = "wndMain",
    path = "CreateBidInputBox",
    post = "OnCreateBidInputBoxChanged",
    tab = {
      link = {
        name = "ahSellBuyout",
        levels = 2,
      },
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
    method = "GuildInitialize",
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
--update cash window
-------------------------------------------------------------------------------
local function updateAmount(cashWindow, editBox, amount)
  --set the new amount
  cashWindow:SetAmount(amount)
  --call post method if needed
  local set = editBox:GetData()
  if set and set.post then
    local addon = Apollo.GetAddon(set.addon)
    if set.container then addon = addon[set.container] end
    addon[set.post](addon, cashWindow, cashWindow)
  end
end

-------------------------------------------------------------------------------
--create error display
-------------------------------------------------------------------------------
local function updateError(window, offsets)
  return window:AddPixie({
    strSprite = "CRB_NameplateSprites:sprNp_VulnerableBarFlash",
    loc = {
      fPoints = {0,0,1,1},
      nOffsets = offsets,
    },
    cr = "AddonError",
  })
end

-------------------------------------------------------------------------------
--read window status and update as needed
-------------------------------------------------------------------------------
function EasyPlatEntry:UpdateWindow(keepOnError)
  --ensure our window is up
  if not self.wndMain or not self.wndMain:IsValid() then return end
  --grab the cash window we're attached to
  local cashWindow = self.wndMain:GetParent()
  --attempt to get value from string
  local editBox = self.wndMain:FindChild("EditBox")
  local good, amount = convertStringToAmount(editBox:GetText())
  if good then
    updateAmount(cashWindow, editBox, amount)
  else
    local errorOffsets
    if keepOnError then
      errorWindow = self.wndMain
      errorOffsets = {5,0,-5,2}
      editBox:SetFocus()
    else
      errorWindow = cashWindow
      errorOffsets = {0,-5,0,5}
    end
    errorPixie = updateError(errorWindow, errorOffsets)
    self.timer = ApolloTimer.Create(0.5, false, "OnPixieTimer", self)
  end
  if good or not keepOnError then
    self.wndMain:Destroy()
    self.wndMain = nil
  end
end

-------------------------------------------------------------------------------
--timer functions
-------------------------------------------------------------------------------
function EasyPlatEntry:OnPixieTimer()
  if errorWindow and errorWindow:IsValid() then
    errorWindow:DestroyPixie(errorPixie)
  end
end

-------------------------------------------------------------------------------
--when user hits escape in the edit box
-------------------------------------------------------------------------------
function EasyPlatEntry:OnEditBoxEscape()
  if self.wndMain and self.wndMain:IsValid() then self.wndMain:Destroy() end
end

-------------------------------------------------------------------------------
--when user clicks off of the pop-up window
-------------------------------------------------------------------------------
function EasyPlatEntry:OnWindowClosed()
  self:UpdateWindow(false)
end

-------------------------------------------------------------------------------
--when user hits enter in the edit box
-------------------------------------------------------------------------------
function EasyPlatEntry:OnEditBoxReturn(wndHandler, wndControl, strText)
  self:UpdateWindow(true)
end

-------------------------------------------------------------------------------
--when user hits tab in the edit box
-------------------------------------------------------------------------------
function EasyPlatEntry:OnEditBoxTab(wndHandler, wndControl, strText)
  self:UpdateWindow(true)
end

-------------------------------------------------------------------------------
--event called by hooked cash window
-------------------------------------------------------------------------------
function EasyPlatEntry:MouseButtonDownEvent(cashWindow, set)
  --destroy the previous window if it hasn't been already
  if self.wndMain and self.wndMain:IsValid() then
    self:UpdateWindow(false)
  end
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
--when slash command entered
-------------------------------------------------------------------------------
function EasyPlatEntry:OnSlashCommand()
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
  -- Apollo.RegisterSlashCommand("easyplatentry", "OnSlashCommand", self)
  -- Apollo.RegisterSlashCommand("epe", "OnSlashCommand", self)
end

-------------------------------------------------------------------------------
--set up addon
-------------------------------------------------------------------------------
local errorPixie, errorWindow
local EasyPlatEntryInst = EasyPlatEntry:new()
EasyPlatEntryInst:Init()
