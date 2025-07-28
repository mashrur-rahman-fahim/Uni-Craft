import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uni_craft/models/study_material.dart';
import 'package:uni_craft/services/study_material_service.dart';
import 'package:uni_craft/widget/enhanced_upload_file.dart';
import 'package:url_launcher/url_launcher.dart';

class StudyMaterials extends StatefulWidget {
  final String userRole;
  final String groupCode;
  
  const StudyMaterials({
    Key? key,
    required this.userRole,
    required this.groupCode,
  }) : super(key: key);

  @override
  State<StudyMaterials> createState() => _StudyMaterialsState();
}

class _StudyMaterialsState extends State<StudyMaterials>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final StudyMaterialService _materialService = StudyMaterialService();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  bool get _isAdmin => widget.userRole == "Administrator";

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffb8d8d8),
      appBar: AppBar(
        backgroundColor: const Color(0xff7a9e9f),
        title: const Text(
          "Study Materials",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isAdmin)
            IconButton(
              onPressed: () => _navigateToUpload(),
              icon: const Icon(Icons.add, color: Colors.white),
              tooltip: 'Upload Material',
            )
          else
            const Padding(
              padding: EdgeInsets.only(right: 16.0),
              child: Icon(Icons.visibility, color: Colors.white70),
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: "Media", icon: Icon(Icons.photo_library)),
            Tab(text: "Files", icon: Icon(Icons.folder)),
            Tab(text: "Links", icon: Icon(Icons.link)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildMaterialsList('image'),
          _buildMaterialsList('file'),
          _buildMaterialsList('link'),
        ],
      ),
    );
  }

  Widget _buildMaterialsList(String type) {
    return StreamBuilder<List<StudyMaterial>>(
      stream: _materialService.getMaterialsByType(widget.groupCode, type),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xff7a9e9f)),
          );
        }

        if (snapshot.hasError) {
          return _buildErrorWidget('Error loading materials: ${snapshot.error}');
        }

        final materials = snapshot.data ?? [];

        if (materials.isEmpty) {
          return _buildEmptyState(type);
        }

        return RefreshIndicator(
          onRefresh: () async {
            setState(() {});
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            physics: const BouncingScrollPhysics(),
            itemCount: materials.length,
            itemBuilder: (context, index) {
              return _buildMaterialCard(materials[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildMaterialCard(StudyMaterial material) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildMaterialHeader(material),
          _buildMaterialContent(material),
          if (_isAdmin) _buildAdminActions(material),
        ],
      ),
    );
  }

  Widget _buildMaterialHeader(StudyMaterial material) {
    final uploadDate = DateTime.tryParse(material.uploadDate);
    final formattedDate = uploadDate != null
        ? DateFormat('MMM dd, yyyy • HH:mm').format(uploadDate)
        : 'Unknown date';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xff7a9e9f).withOpacity(0.1),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getTypeIcon(material.type),
            color: const Color(0xff7a9e9f),
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  material.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMaterialContent(StudyMaterial material) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (material.description != null && material.description!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                material.description!,
                style: TextStyle(color: Colors.grey[700]),
              ),
            ),
          if (material.isImage) _buildImageContent(material),
          if (material.isFile) _buildFileContent(material),
          if (material.isLink) _buildLinkContent(material),
        ],
      ),
    );
  }

  Widget _buildImageContent(StudyMaterial material) {
    return GestureDetector(
      onTap: () => _launchUrl(material.url),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CachedNetworkImage(
          imageUrl: material.url,
          height: 200,
          width: double.infinity,
          fit: BoxFit.cover,
          placeholder: (context, url) => Container(
            height: 200,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xff7a9e9f)),
            ),
          ),
          errorWidget: (context, url, error) => Container(
            height: 200,
            color: Colors.grey[200],
            child: const Center(
              child: Icon(Icons.error, size: 50, color: Colors.grey),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFileContent(StudyMaterial material) {
    return InkWell(
      onTap: () => _launchUrl(material.url),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xff7a9e9f).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xff7a9e9f).withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              _getFileIcon(material.name),
              color: const Color(0xff7a9e9f),
              size: 32,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    material.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                  if (material.fileSize != null)
                    Text(
                      _formatFileSize(material.fileSize!),
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.download,
              color: Color(0xff7a9e9f),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkContent(StudyMaterial material) {
    return InkWell(
      onTap: () => _launchUrl(material.url),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.blue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.blue.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.link,
              color: Colors.blue,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                material.url,
                style: const TextStyle(
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const Icon(
              Icons.open_in_new,
              color: Colors.blue,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdminActions(StudyMaterial material) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(12),
          bottomRight: Radius.circular(12),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          TextButton.icon(
            onPressed: () => _deleteMaterial(material),
            icon: const Icon(Icons.delete, color: Colors.red, size: 18),
            label: const Text(
              'Delete',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String type) {
    String message;
    IconData icon;
    
    switch (type) {
      case 'image':
        message = 'No images uploaded yet';
        icon = Icons.photo_library_outlined;
        break;
      case 'file':
        message = 'No files uploaded yet';
        icon = Icons.folder_outlined;
        break;
      case 'link':
        message = 'No links shared yet';
        icon = Icons.link_outlined;
        break;
      default:
        message = 'No materials available';
        icon = Icons.folder_outlined;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          if (_isAdmin) ...[
            const SizedBox(height: 8),
            Text(
              'Tap the + button to upload materials',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[500],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80,
            color: Colors.red,
          ),
          const SizedBox(height: 16),
          Text(
            'Oops! Something went wrong',
            style: TextStyle(
              fontSize: 18,
              color: Colors.grey[800],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xff7a9e9f),
              foregroundColor: Colors.white,
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image;
      case 'file':
        return Icons.description;
      case 'link':
        return Icons.link;
      default:
        return Icons.insert_drive_file;
    }
  }

  IconData _getFileIcon(String fileName) {
    final extension = fileName.toLowerCase().split('.').last;
    
    switch (extension) {
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
        return Icons.description;
      case 'xls':
      case 'xlsx':
        return Icons.table_chart;
      case 'ppt':
      case 'pptx':
        return Icons.slideshow;
      case 'zip':
      case 'rar':
        return Icons.archive;
      case 'mp4':
      case 'avi':
      case 'mov':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
        return Icons.audio_file;
      default:
        return Icons.insert_drive_file;
    }
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }

  Future<void> _navigateToUpload() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => UploadFile(groupCode: widget.groupCode),
      ),
    );
    
    if (result == true) {
      // Refresh the current tab
      setState(() {});
    }
  }

  Future<void> _launchUrl(String url) async {
    try {
      final uri = Uri.parse(url);
      if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        throw Exception('Could not launch $url');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error opening file: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _deleteMaterial(StudyMaterial material) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Material'),
        content: Text('Are you sure you want to delete "${material.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      
      try {
        final success = await _materialService.deleteMaterial(material.id);
        
        if (success && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Material deleted successfully'),
              backgroundColor: Colors.green,
            ),
          );
        } else if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to delete material'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error deleting material: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }
}
