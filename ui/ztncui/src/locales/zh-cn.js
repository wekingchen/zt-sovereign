/*
  ztncui 简体中文界面词汇表
  仅用于显示层；不会修改 ZeroTier API 字段名、URL 或持久化数据结构。
*/

const labels = {
  nwid: '网络 ID',
  id: '成员 ID',
  name: '名称',
  private: '访问控制',
  creationTime: '创建时间',
  enableBroadcast: '允许广播',
  multicastLimit: '组播限制',
  mtu: 'MTU',
  routes: '受管路由',
  ipAssignmentPools: 'IP 分配池',
  v4AssignMode: 'IPv4 分配模式',
  v6AssignMode: 'IPv6 分配模式',
  dns: 'DNS 设置',
  rules: '规则',
  capabilities: '能力',
  tags: '标签',
  revision: '修订号',
  remoteTraceTarget: '远程跟踪目标',
  remoteTraceLevel: '远程跟踪级别',
  authorized: '已授权',
  activeBridge: '活动桥接',
  ipAssignments: 'IP 分配',
  noAutoAssignIps: '禁用自动 IP 分配',
  address: 'ZeroTier 地址',
  identity: '身份',
  objtype: '对象类型',
  clock: '时钟',
  online: '在线状态',
  version: '版本',
  versionMajor: '主版本号',
  versionMinor: '次版本号',
  versionRev: '修订版本号',
  latency: '延迟',
  paths: '路径',
  preferred: '首选路径',
  lastSend: '上次发送',
  lastReceive: '上次接收',
  lastUnicastFrame: '上次单播帧',
  lastMulticastFrame: '上次组播帧',
  physicalAddress: '物理地址',
  peer: '节点状态',
  deleted: '已删除',
  type: '类型',
  target: '目标网段',
  via: '网关',
  ipRangeStart: '起始 IP',
  ipRangeEnd: '结束 IP',
  domain: '域名',
  servers: 'DNS 服务器',
  authTokens: '授权令牌',
  authorizationEndpoint: '授权端点',
  clientId: '客户端 ID',
  rulesSource: '规则源',
  ssoEnabled: '启用 SSO',
  lastAuthorizedTime: '上次授权时间',
  lastDeauthorizedTime: '上次取消授权时间',
  authenticationExpiryTime: '认证到期时间',
  authenticationURL: '认证地址',
  vMajor: '主版本号',
  vMinor: '次版本号',
  vRev: '修订版本号',
  vProto: '协议版本',
  protocolVersion: '协议版本',
  bondingPolicy: '链路聚合策略',
  tunneled: '隧道连接',
  expired: '已过期',
  supportsRulesEngine: '支持规则引擎',
  physicalAddr: '物理地址',
  lastSeen: '上次在线时间',
  lastOnline: '上次上线时间',
  lastAuthorized: '上次授权',
  lastDeauthorized: '上次取消授权'
};

const titles = {
  private: '访问控制',
  routes: '受管路由',
  ipAssignmentPools: 'IP 分配池',
  v4AssignMode: 'IPv4 分配模式',
  v6AssignMode: 'IPv6 分配模式',
  dns: 'DNS 设置',
  ipAssignments: 'IP 分配'
};

function label(key) {
  return labels[key] || key;
}

function title(key) {
  return titles[key] || label(key);
}

module.exports = { label, title };
