import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../bluetooth/bluetooth_permissions.dart';
import '../../data/models/chat.dart';
import '../../utils/time_ago.dart';
import '../providers/ble_provider.dart';
import '../providers/chat_provider.dart';
import '../providers/settings_provider.dart';
import '../theme/colors.dart';
import '../widgets/bluetooth_status_chip.dart';
import '../widgets/empty_state.dart';
import '../widgets/mesh_topology_view.dart';
import 'settings_screen.dart';

/// Main home dashboard with bottom navigation: Chats, Cluster Topology, and Settings.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      BluetoothPermissionsManager.requestPermissions();
    });
  }

  @override
  Widget build(BuildContext context) {
    final bleState = ref.watch(bleProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('BlueMesh'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: BluetoothStatusChip(
              isBluetoothOn: bleState.isBluetoothOn,
              isScanning: bleState.isScanning,
              peerCount: bleState.connectedPeersCount,
              isDualRole: bleState.isPeripheralActive,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            tooltip: 'Mesh Diagnostics',
            onPressed: () => context.push('/diagnostics'),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentTabIndex,
        children: [
          _buildChatsTab(),
          _buildClusterTab(settings.displayName, bleState),
          const SettingsScreen(),
        ],
      ),
      floatingActionButton: _currentTabIndex == 0
          ? FloatingActionButton(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              onPressed: () => context.push('/contacts'),
              child: const Icon(Icons.chat_bubble_outline_rounded),
            )
          : null,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentTabIndex,
        onTap: (index) => setState(() => _currentTabIndex = index),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_outlined),
            activeIcon: Icon(Icons.chat_rounded),
            label: 'Chats',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.hub_outlined),
            activeIcon: Icon(Icons.hub_rounded),
            label: 'Cluster',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildChatsTab() {
    final chatsAsync = ref.watch(chatsListProvider);

    return chatsAsync.when(
      data: (chats) {
        if (chats.isEmpty) {
          return EmptyStateView(
            icon: Icons.chat_bubble_outline_rounded,
            title: 'No Conversations Yet',
            message: 'Discover nearby peers in your Bluetooth cluster to start chatting without internet.',
            action: ElevatedButton.icon(
              onPressed: () => context.push('/contacts'),
              icon: const Icon(Icons.person_search_rounded),
              label: const Text('Discover Cluster Peers'),
            ),
          );
        }

        return ListView.separated(
          itemCount: chats.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, index) {
            final chat = chats[index];
            return _buildChatTile(chat);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error loading chats: $e')),
    );
  }

  Widget _buildChatTile(Chat chat) {
    final initials = chat.peerName.trim().isNotEmpty
        ? chat.peerName.trim().substring(0, 1).toUpperCase()
        : '?';

    return ListTile(
      onTap: () {
        context.push(
          '/chat?peerId=${chat.peerId}&peerName=${Uri.encodeComponent(chat.peerName)}',
        );
      },
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: AppColors.primaryDark.withOpacity(0.3),
        child: Text(
          initials,
          style: const TextStyle(
            color: AppColors.primaryLight,
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
      ),
      title: Text(
        chat.peerName,
        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
      ),
      subtitle: Text(
        chat.lastMessage.isEmpty ? 'Tap to start conversation' : chat.lastMessage,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: chat.unreadCount > 0 ? Colors.white : AppColors.offlineGrey,
          fontWeight: chat.unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            TimeAgo.formatTimeOnly(chat.lastMessageTime),
            style: const TextStyle(fontSize: 12, color: AppColors.offlineGrey),
          ),
          const SizedBox(height: 4),
          if (chat.unreadCount > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${chat.unreadCount}',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildClusterTab(String myName, BleState bleState) {
    if (bleState.discoveredPeers.isEmpty) {
      return EmptyStateView(
        icon: Icons.bluetooth_searching_rounded,
        title: 'Scanning for Cluster Nodes',
        message: 'Looking for nearby devices running BlueMesh within 10–30 meters.\nKeep Bluetooth turned on.',
      );
    }

    return MeshTopologyView(
      myName: myName,
      peers: bleState.discoveredPeers,
      onPeerSelected: (peer) {
        context.push(
          '/chat?peerId=${peer.deviceId}&peerName=${Uri.encodeComponent(peer.advertisedName)}',
        );
      },
    );
  }
}
