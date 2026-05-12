/* Disable SFTP subsystem support - we only need SCP for file transfers.
 * This prevents Dropbear from attempting to execute /usr/libexec/sftp-server
 * which is only provided by the full OpenSSH package (~600KB overhead).
 *
 * SCP protocol works independently of SFTP and does not require this.
 */
#define DROPBEAR_SFTPSERVER 0
