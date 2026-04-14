export async function onRequest(context) {
  // 目标服务器的公网 IP 和 API 端口
  const targetServerUrl = "http://YOUR_SERVER_IP:5000/api/sysctl";

  try {
    // 由 Cloudflare 边缘节点向你的服务器发起请求 [Ref 1, Section 3]
    const response = await fetch(targetServerUrl, {
        method: 'GET',
        headers: {
            'Content-Type': 'application/json',
            // 如果后端配置了 Token 验证，在此处添加
            // 'Authorization': 'Bearer YOUR_SECRET_TOKEN'
        }
    });

    const data = await response.json();

    // 将目标服务器的数据返回给前端应用
    return new Response(JSON.stringify(data), {
      headers: {
        "Content-Type": "application/json",
      },
    });
  } catch (err) {
    return new Response(JSON.stringify({ error: "Failed to fetch sysctl.conf" }), { status: 500 });
  }
}
