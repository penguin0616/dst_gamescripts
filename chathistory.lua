require "class"

local MAX_CHAT_HISTORY = 100

local ChatHistoryManager = Class(function(self)
    self.listeners = {}

    self.history = {}

    self.request_history_start = 1
    self.history_start = self.MAX_CHAT_HISTORY
end)

function ChatHistoryManager:JoinServer()
    self.join_server = true
end

ChatHistoryManager.MAX_CHAT_HISTORY = MAX_CHAT_HISTORY

function ChatHistoryManager:GetDisplayName(name, prefab)
    return name ~= "" and name or STRINGS.UI.SERVERADMINSCREEN.UNKNOWN_USER_NAME
end

function ChatHistoryManager:OnAnnouncement(message, colour, announce_type)
    if self.join_server then return end
    local chat_message = self:AddToHistory(ChatTypes.Announcement, nil, message, colour, announce_type)
    for fn in pairs(self.listeners) do
        fn(chat_message)
    end
end

function ChatHistoryManager:OnSkinAnnouncement(user_name, user_colour, skin_name)
    if self.join_server then return end
    local chat_message = self:AddToHistory(ChatTypes.SkinAnnouncement, user_name, skin_name, user_colour)
    for fn in pairs(self.listeners) do
        fn(chat_message)
    end
end

function ChatHistoryManager:OnSystemMessage(message)
    if self.join_server then return end
    local chat_message = self:AddToHistory(ChatTypes.SystemMessage, STRINGS.UI.SERVERADMINSCREEN.SYSTEMMESSAGE, message, WHITE)
    for fn in pairs(self.listeners) do
        fn(chat_message)
    end
end

function ChatHistoryManager:OnSay(guid, userid, name, prefab, message, colour, whisper, isemote, user_vanity)
    if self.join_server then return end
    name = self:GetDisplayName(name, prefab)
    local hud = ThePlayer and ThePlayer.HUD or nil
    local entity = Ents[guid]
    if not whisper or (entity and hud and (hud:HasTargetIndicator(entity) or entity.entity:FrustumCheck())) then
        local chat_message
        if isemote then
            chat_message = self:AddToHistory(ChatTypes.Emote, nil, name.." "..message, colour, nil, true, true)
        else
            chat_message = self:AddToHistory(ChatTypes.Message, name, message, colour, GetRemotePlayerVanityItem(user_vanity or {}, "profileflair") or "default", whisper, whisper)
        end
        for fn in pairs(self.listeners) do
            fn(chat_message)
        end
    end
end

function ChatHistoryManager:SendCommandResponse(messages)
    if self.join_server then return end
    if type(messages) == "string" then
        messages = {messages}
    end

    for _, message in ipairs(messages) do
        local chat_message = self:AddToHistory(ChatTypes.CommandResponse, nil, message, WHITE, nil, nil, true)
        for fn in pairs(self.listeners) do
            fn(chat_message)
        end
    end
end

function ChatHistoryManager:GenerateChatMessage(type, sender, message, colour, icondata, whisper, localonly)
    local chat_message = {}

    local is_announcement = type == ChatTypes.Announcement

    chat_message.type = type
    chat_message.localonly = localonly or nil

    if not is_announcement then
        if sender then
            if whisper then
                sender = STRINGS.UI.CHATINPUTSCREEN.WHISPER_DESIGNATOR.." "..sender
            end
            chat_message.sender = sender

            chat_message.s_colour = colour
        end
    end

    chat_message.message = message

    local m_colour = SAY_COLOR
    if type ~= ChatTypes.Message then
        m_colour = colour
    elseif whisper then
        m_colour = WHISPER_COLOR
    end
    chat_message.m_colour = m_colour

    chat_message.icondata = icondata

    return chat_message
end

function ChatHistoryManager:AddToHistory(type, sender, message, colour, icondata, whisper, localonly)
    if self.join_server then return end

    local chat_message = self:GenerateChatMessage(type, sender, message, colour, icondata, whisper, localonly)

    self.history_start = (self.history_start % self.MAX_CHAT_HISTORY) + 1

    if self.request_history_start then
        self.request_history_start = self.request_history_start + 1
        if self.request_history_start >= self.MAX_CHAT_HISTORY then
            self.request_history_start = nil
        end
    end

    self.max_chat_history_plus_one = self.history[self.history_start]

    self.history[self.history_start] = chat_message
    return chat_message
end

local function get_absolute_index(self, idx)
    local abs_idx = self.history_start - (idx - 1)
    if abs_idx < 1 then abs_idx = abs_idx + self.MAX_CHAT_HISTORY end
    return abs_idx
end

function ChatHistoryManager:AddToHistoryAtIndex(chat_message, index)
    if self.join_server or IsTableEmpty(chat_message) then return end

    local count = math.max(#chat_message, 1)

    for i = 1, count do
        self.history_start = (self.history_start % self.MAX_CHAT_HISTORY) + 1
    end

    self.max_chat_history_plus_one = self.history[self.history_start]

    if self.request_history_start and index > self.request_history_start then
        self.request_history_start = self.request_history_start + count
        if self.request_history_start >= self.MAX_CHAT_HISTORY then
            self.request_history_start = nil
        end
    end

    for i = 1, index - 1 do
        local new_index = get_absolute_index(self, i)
        local current_index = get_absolute_index(self, i+count)
        self.history[new_index] = self.history[current_index]
        self.history[current_index] = nil
    end

    if count > 1 then
        for i, v in ipairs(chat_message) do
            local insert_index = get_absolute_index(self, (index - 1) + count - (i - 1))
            self.history[insert_index] = v
        end
    else
        local insert_index = get_absolute_index(self, index)
        self.history[insert_index] = chat_message
    end
end

function ChatHistoryManager:GetChatMessageAtIndex(idx)
    --idx 1 returns the newest chat message
    --idx self.MAX_CHAT_HISTORY returns the oldest chat message
    local history_index = get_absolute_index(self, idx)
    return self.history[history_index]
end

function ChatHistoryManager:GetLastDeletedChatMessage()
    return self.max_chat_history_plus_one
end

function ChatHistoryManager:AddChatHistoryListener(fn)
    self.listeners[fn] = true
end

function ChatHistoryManager:RemoveChatHistoryListener(fn)
    self.listeners[fn] = nil
end

function ChatHistoryManager:HasHistory()
    return not IsTableEmpty(self.history)
end

function ChatHistoryManager:AddJoinMessageToHistory(type, sender, message, colour, icondata, whisper, localonly)
    local request_history_start = self.request_history_start
    self.request_history_start = nil
    if not request_history_start then return end

    local chat_message = self:GenerateChatMessage(type, sender, message, colour, icondata, whisper, localonly)

    self:AddToHistoryAtIndex(chat_message, request_history_start)
end

function ChatHistoryManager:RequestChatHistory()
    if self.join_server or not self.request_history_start then return end

    local last_message_hash
    for i = self.request_history_start, self.MAX_CHAT_HISTORY do
        local message = self:GetChatMessageAtIndex(i)
        if not message then
            return
        end

        if not message.localonly then

            last_message_hash = hash(message.message)
            break
        end
    end

    if not last_message_hash then
        return
    end

    local first_message_hash
    for i = self.request_history_start - 1, 1, -1 do
        local message = self:GetChatMessageAtIndex(i)
        if not message then
            return
        end

        if not message.localonly then
            first_message_hash = hash(message.message)
            break
        end
    end

    SendRPCToServer(RPC.GetChatHistory, last_message_hash, first_message_hash)
end

function ChatHistoryManager:SendChatHistory(userid, last_message_hash, first_message_hash)
    local found_first_message = first_message_hash == nil

    local messages_to_send = {}
    for i = 1, self.MAX_CHAT_HISTORY do
        local message = self:GetChatMessageAtIndex(i)
        if not message then
            return
        end

        if not message.localonly then
            --print(message.message, last_message_hash, first_message_hash, hash(message.message))
            if not found_first_message then
                found_first_message = first_message_hash == hash(message.message)
            elseif last_message_hash == hash(message.message) then
                break
            else
                table.insert(messages_to_send, message)
            end
        end
    end

    if IsTableEmpty(messages_to_send) then
        return
    end

    SendRPCToClient(CLIENT_RPC.RecieveChatHistory, userid, ZipAndEncodeString(table.reverse(messages_to_send)))
end

function ChatHistoryManager:RecieveChatHistory(chat_history)
    local request_history_start = self.request_history_start
    self.request_history_start = nil
    if not request_history_start then return end

    local history = DecodeAndUnzipString(chat_history)

    self:AddToHistoryAtIndex(history, request_history_start)
end

function ChatHistoryManager:GetChatHistory()
    self.history.history_start = self.history_start
    local data = ZipAndEncodeSaveData(self.history)
    self.history.history_start = nil
    return data
end

function ChatHistoryManager:SetChatHistory(history)
    self.history = DecodeAndUnzipSaveData(history)
    self.history_start = self.history.history_start
    self.history.history_start = nil

    self.request_history_start = 1
end

ChatTypes = {
    Message = 1,
    Emote = 2,
    Announcement = 3,
    SkinAnnouncement = 4,
    SystemMessage = 5,
    CommandResponse = 6,
}

ChatHistory = ChatHistoryManager()