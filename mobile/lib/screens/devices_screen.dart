import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/hub_state.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HubState>().refreshDevices();
    });
  }

  @override
  Widget build(BuildContext context) {
    final hub = context.watch<HubState>();
    return Scaffold(
      appBar: AppBar(
        title: const Text('在线设备'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => hub.refreshDevices(),
          ),
        ],
      ),
      body: hub.devices.isEmpty
          ? const Center(child: Text('暂无设备记录\n连接后会自动心跳上报', textAlign: TextAlign.center))
          : ListView.builder(
              itemCount: hub.devices.length,
              itemBuilder: (ctx, i) {
                final d = hub.devices[i];
                final id = '${d['device_id'] ?? ''}';
                final name = '${d['name'] ?? 'Device'}';
                final platform = '${d['platform'] ?? ''}';
                final online = d['online'] == 1 || d['online'] == true;
                final kicked = d['kicked'] == 1 || d['kicked'] == true;
                final isMe = id == hub.deviceId;
                return ListTile(
                  leading: Icon(
                    online ? Icons.smartphone : Icons.phonelink_off,
                    color: kicked
                        ? Colors.redAccent
                        : online
                            ? Colors.greenAccent
                            : Colors.white38,
                  ),
                  title: Text('$name${isMe ? '（本机）' : ''}'),
                  subtitle: Text('$platform\n$id\n${d['last_seen'] ?? ''}'),
                  isThreeLine: true,
                  trailing: isMe
                      ? null
                      : (kicked
                          ? const Text('已踢', style: TextStyle(color: Colors.redAccent))
                          : TextButton(
                              onPressed: () async {
                                final ok = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('踢下线？'),
                                    content: Text('确定踢掉 $name ？'),
                                    actions: [
                                      TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('取消')),
                                      FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('踢下线')),
                                    ],
                                  ),
                                );
                                if (ok == true) await hub.kickDevice(id);
                              },
                              child: const Text('踢下线'),
                            )),
                );
              },
            ),
    );
  }
}
