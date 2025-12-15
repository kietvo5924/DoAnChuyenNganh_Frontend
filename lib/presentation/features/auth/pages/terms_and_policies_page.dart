import 'package:flutter/material.dart';

class TermsAndPoliciesPage extends StatelessWidget {
  const TermsAndPoliciesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Điều khoản & Chính sách')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _H('Hiệu lực'),
            Text(
              'Điều khoản & Chính sách này có hiệu lực từ 15/12/2025 và áp dụng khi bạn sử dụng ứng dụng PlanMate ("Ứng dụng").\n\n'
              'Bằng việc tạo tài khoản hoặc sử dụng Ứng dụng, bạn xác nhận đã đọc, hiểu và đồng ý với các điều khoản dưới đây.',
            ),
            SizedBox(height: 16),
            _H('1) Định nghĩa'),
            Text(
              '• "Bạn", "Người dùng": cá nhân tạo tài khoản/đăng nhập và sử dụng Ứng dụng.\n'
              '• "Chúng tôi": đội ngũ/đơn vị vận hành PlanMate.\n'
              '• "Nội dung": dữ liệu bạn tạo trong Ứng dụng như lịch, công việc, mô tả, nhãn, lời nhắc, v.v.',
            ),
            SizedBox(height: 16),
            _H('2) Điều kiện sử dụng'),
            Text(
              'Bạn cam kết: \n'
              '• Cung cấp thông tin chính xác khi đăng ký.\n'
              '• Chịu trách nhiệm bảo mật tài khoản/mật khẩu của mình.\n'
              '• Không sử dụng Ứng dụng cho mục đích trái pháp luật hoặc gây hại cho người khác.\n'
              '• Tuân thủ Tiêu chuẩn cộng đồng và các quy định liên quan trong Điều khoản này.',
            ),
            SizedBox(height: 16),
            _H('3) Tài khoản & bảo mật'),
            Text(
              '• Bạn tự chịu trách nhiệm cho mọi hoạt động diễn ra bằng tài khoản của bạn.\n'
              '• Không chia sẻ mật khẩu/OTP cho người khác.\n'
              '• Nếu nghi ngờ bị truy cập trái phép, bạn cần đổi mật khẩu và/hoặc đăng xuất trên các thiết bị, đồng thời liên hệ hỗ trợ nếu cần.\n'
              '• Chúng tôi có thể tạm khóa tài khoản khi phát hiện dấu hiệu gian lận hoặc vi phạm Điều khoản.',
            ),
            SizedBox(height: 16),
            _H('4) Quyền sở hữu & nội dung người dùng'),
            Text(
              '• Bạn giữ quyền sở hữu đối với Nội dung bạn tạo ra.\n'
              '• Bạn cấp cho chúng tôi quyền cần thiết để lưu trữ, xử lý và hiển thị Nội dung nhằm cung cấp tính năng của Ứng dụng (ví dụ: đồng bộ, chia sẻ lịch theo quyền, sao lưu).\n'
              '• Bạn không được đăng tải hoặc chia sẻ Nội dung xâm phạm quyền sở hữu trí tuệ, quyền riêng tư, hoặc quyền hợp pháp của người khác.',
            ),
            SizedBox(height: 16),
            _H('5) Tiêu chuẩn cộng đồng (nội dung bị cấm)'),
            Text(
              'Bạn không được sử dụng Ứng dụng để tạo/lưu/chia sẻ Nội dung hoặc thực hiện hành vi:\n'
              '• Vi phạm pháp luật, kích động hành vi phạm pháp.\n'
              '• Quấy rối, đe doạ, bắt nạt, bôi nhọ danh dự người khác.\n'
              '• Kỳ thị/thù ghét dựa trên chủng tộc, quốc tịch, tôn giáo, giới tính, xu hướng tính dục, khuyết tật hoặc đặc điểm được pháp luật bảo vệ.\n'
              '• Nội dung khiêu dâm, khai thác tình dục, đặc biệt liên quan trẻ vị thành niên.\n'
              '• Nội dung bạo lực cực đoan, cổ vũ tự hại, hoặc hướng dẫn gây hại.\n'
              '• Spam, lừa đảo, giả mạo, phát tán mã độc, tấn công hệ thống.\n'
              '• Thu thập dữ liệu người khác trái phép hoặc xâm phạm quyền riêng tư.\n\n'
              'Hậu quả: chúng tôi có thể gỡ/ẩn Nội dung, hạn chế tính năng, tạm khoá hoặc chấm dứt tài khoản tùy mức độ vi phạm.',
            ),
            SizedBox(height: 16),
            _H('6) Chia sẻ lịch & quyền truy cập'),
            Text(
              '• Khi bạn chia sẻ lịch, bạn có thể cấp quyền: chỉ xem (VIEW_ONLY) hoặc chỉnh sửa (EDIT).\n'
              '• Người được chia sẻ phải tuân thủ Điều khoản này khi truy cập lịch.\n'
              '• Bạn chịu trách nhiệm cân nhắc trước khi cấp quyền EDIT cho người khác.',
            ),
            SizedBox(height: 16),
            _H('7) Chính sách bảo mật (tóm tắt)'),
            Text(
              'Chúng tôi coi trọng quyền riêng tư của bạn. Dưới đây là tóm tắt về dữ liệu và cách xử lý (có thể thay đổi theo phiên bản):\n\n'
              '7.1 Dữ liệu có thể thu thập\n'
              '• Thông tin tài khoản: họ tên, email, thông tin đăng nhập.\n'
              '• Dữ liệu sử dụng: lịch, công việc, nhãn, cài đặt, trạng thái đồng bộ, trạng thái hoàn thành theo ngày.\n'
              '• Dữ liệu kỹ thuật: nhật ký lỗi cơ bản để cải thiện ổn định (nếu có).\n\n'
              '7.2 Mục đích sử dụng\n'
              '• Cung cấp chức năng chính: tạo lịch/công việc, nhắc việc, đồng bộ, chia sẻ.\n'
              '• Bảo mật và ngăn chặn gian lận.\n'
              '• Cải thiện chất lượng dịch vụ (ví dụ: khắc phục lỗi).\n\n'
              '7.3 Chia sẻ dữ liệu\n'
              '• Chúng tôi không bán dữ liệu cá nhân của bạn.\n'
              '• Dữ liệu chỉ được chia sẻ theo: (a) tính năng bạn chủ động sử dụng (ví dụ chia sẻ lịch), (b) yêu cầu pháp lý hợp lệ, hoặc (c) nhà cung cấp hạ tầng cần thiết để vận hành (nếu có), theo phạm vi tối thiểu cần thiết.\n\n'
              '7.4 Lưu trữ & bảo mật\n'
              '• Dữ liệu có thể được lưu trên thiết bị và/hoặc máy chủ để phục vụ đồng bộ.\n'
              '• Chúng tôi áp dụng các biện pháp hợp lý để bảo vệ dữ liệu, nhưng không thể đảm bảo an toàn tuyệt đối trước mọi rủi ro.\n\n'
              '7.5 Quyền của bạn\n'
              '• Bạn có thể cập nhật thông tin, xoá nội dung trong Ứng dụng.\n'
              '• Bạn có thể yêu cầu hỗ trợ về quyền riêng tư theo thông tin liên hệ bên dưới.',
            ),
            SizedBox(height: 16),
            _H('8) Giới hạn trách nhiệm'),
            Text(
              '• Ứng dụng được cung cấp theo hiện trạng. Chúng tôi nỗ lực đảm bảo ổn định, nhưng có thể có gián đoạn do lỗi, mạng, hoặc yếu tố ngoài kiểm soát.\n'
              '• Chúng tôi không chịu trách nhiệm cho thiệt hại gián tiếp phát sinh do việc bạn sử dụng hoặc không thể sử dụng Ứng dụng, trong phạm vi pháp luật cho phép.',
            ),
            SizedBox(height: 16),
            _H('9) Chấm dứt / tạm khóa'),
            Text(
              'Chúng tôi có thể tạm khóa hoặc chấm dứt tài khoản khi bạn vi phạm Điều khoản, hoặc khi có yêu cầu pháp lý. Bạn cũng có thể ngừng sử dụng Ứng dụng bất kỳ lúc nào.',
            ),
            SizedBox(height: 16),
            _H('10) Thay đổi điều khoản'),
            Text(
              'Chúng tôi có thể cập nhật Điều khoản & Chính sách theo thời gian. Khi có thay đổi quan trọng, chúng tôi sẽ cố gắng thông báo theo cách phù hợp trong Ứng dụng.',
            ),
            SizedBox(height: 16),
            _H('11) Liên hệ'),
            Text(
              'Nếu bạn có câu hỏi về Điều khoản/Chính sách hoặc muốn báo cáo vi phạm, vui lòng liên hệ bộ phận hỗ trợ của PlanMate (theo kênh hỗ trợ được cung cấp trong Ứng dụng).',
            ),
            SizedBox(height: 24),
            Text(
              'Ghi chú: Nội dung này mang tính mô tả cho ứng dụng học tập/dự án. Nếu triển khai thương mại, bạn nên tham khảo tư vấn pháp lý để hoàn thiện điều khoản phù hợp.',
              style: TextStyle(fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _H extends StatelessWidget {
  final String text;
  const _H(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
