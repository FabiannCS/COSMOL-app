"""
Modelos ORM de SQLAlchemy para PostgreSQL:
- User: Identidad digital (celular, password_hash, estado, intentos fallidos).
- UserAccount: Vinculación de Códigos de Socio con roles (Titular vs Consulta/Pago).
- UserDevice: Control de dispositivos activos y tokens FCM.
- OtpLog: Auditoría de códigos OTP generados y consumidos.
"""
