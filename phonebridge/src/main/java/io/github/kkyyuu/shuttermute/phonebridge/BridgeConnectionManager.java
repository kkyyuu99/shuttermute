package io.github.kkyyuu.shuttermute.phonebridge;

import android.content.Context;
import android.os.Build;
import android.sun.misc.BASE64Encoder;
import android.sun.security.provider.X509Factory;
import android.sun.security.x509.AlgorithmId;
import android.sun.security.x509.CertificateAlgorithmId;
import android.sun.security.x509.CertificateExtensions;
import android.sun.security.x509.CertificateIssuerName;
import android.sun.security.x509.CertificateSerialNumber;
import android.sun.security.x509.CertificateSubjectName;
import android.sun.security.x509.CertificateValidity;
import android.sun.security.x509.CertificateVersion;
import android.sun.security.x509.CertificateX509Key;
import android.sun.security.x509.KeyIdentifier;
import android.sun.security.x509.PrivateKeyUsageExtension;
import android.sun.security.x509.SubjectKeyIdentifierExtension;
import android.sun.security.x509.X500Name;
import android.sun.security.x509.X509CertImpl;
import android.sun.security.x509.X509CertInfo;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;

import java.io.File;
import java.io.FileInputStream;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.KeyPair;
import java.security.KeyPairGenerator;
import java.security.NoSuchAlgorithmException;
import java.security.PrivateKey;
import java.security.PublicKey;
import java.security.SecureRandom;
import java.security.cert.Certificate;
import java.security.cert.CertificateEncodingException;
import java.security.cert.CertificateException;
import java.security.cert.CertificateFactory;
import java.security.spec.EncodedKeySpec;
import java.security.spec.InvalidKeySpecException;
import java.security.spec.PKCS8EncodedKeySpec;
import java.util.Date;
import java.util.Random;

import io.github.muntashirakon.adb.AbsAdbConnectionManager;

public class BridgeConnectionManager extends AbsAdbConnectionManager {
    private static AbsAdbConnectionManager instance;

    @NonNull
    public static synchronized AbsAdbConnectionManager getInstance(@NonNull Context context) throws Exception {
        if (instance == null) {
            instance = new BridgeConnectionManager(context.getApplicationContext());
        }
        return instance;
    }

    private final PrivateKey privateKey;
    private final Certificate certificate;

    private BridgeConnectionManager(@NonNull Context context) throws Exception {
        setApi(Build.VERSION.SDK_INT);
        PrivateKey storedPrivateKey = readPrivateKeyFromFile(context);
        Certificate storedCertificate = readCertificateFromFile(context);
        if (storedPrivateKey == null || storedCertificate == null) {
            KeyPairGenerator keyPairGenerator = KeyPairGenerator.getInstance("RSA");
            keyPairGenerator.initialize(2048, SecureRandom.getInstance("SHA1PRNG"));
            KeyPair keyPair = keyPairGenerator.generateKeyPair();
            PublicKey publicKey = keyPair.getPublic();
            storedPrivateKey = keyPair.getPrivate();

            String subject = "CN=ShutterMute Phone Bridge";
            String algorithmName = "SHA512withRSA";
            long expiryDate = System.currentTimeMillis() + 86400000L;
            CertificateExtensions certificateExtensions = new CertificateExtensions();
            certificateExtensions.set(
                    "SubjectKeyIdentifier",
                    new SubjectKeyIdentifierExtension(new KeyIdentifier(publicKey).getIdentifier()));
            X500Name x500Name = new X500Name(subject);
            Date notBefore = new Date();
            Date notAfter = new Date(expiryDate);
            certificateExtensions.set(
                    "PrivateKeyUsage",
                    new PrivateKeyUsageExtension(notBefore, notAfter));
            CertificateValidity certificateValidity = new CertificateValidity(notBefore, notAfter);
            X509CertInfo x509CertInfo = new X509CertInfo();
            x509CertInfo.set("version", new CertificateVersion(2));
            x509CertInfo.set(
                    "serialNumber",
                    new CertificateSerialNumber(new Random().nextInt() & Integer.MAX_VALUE));
            x509CertInfo.set("algorithmID", new CertificateAlgorithmId(AlgorithmId.get(algorithmName)));
            x509CertInfo.set("subject", new CertificateSubjectName(x500Name));
            x509CertInfo.set("key", new CertificateX509Key(publicKey));
            x509CertInfo.set("validity", certificateValidity);
            x509CertInfo.set("issuer", new CertificateIssuerName(x500Name));
            x509CertInfo.set("extensions", certificateExtensions);
            X509CertImpl x509CertImpl = new X509CertImpl(x509CertInfo);
            x509CertImpl.sign(storedPrivateKey, algorithmName);
            storedCertificate = x509CertImpl;

            writePrivateKeyToFile(context, storedPrivateKey);
            writeCertificateToFile(context, storedCertificate);
        }

        privateKey = storedPrivateKey;
        certificate = storedCertificate;
    }

    @NonNull
    @Override
    protected PrivateKey getPrivateKey() {
        return privateKey;
    }

    @NonNull
    @Override
    protected Certificate getCertificate() {
        return certificate;
    }

    @NonNull
    @Override
    protected String getDeviceName() {
        return "ShutterMute Phone Bridge";
    }

    @Nullable
    private static Certificate readCertificateFromFile(@NonNull Context context)
            throws IOException, CertificateException {
        File certFile = new File(context.getFilesDir(), "phonebridge-cert.pem");
        if (!certFile.exists()) {
            return null;
        }
        try (InputStream cert = new FileInputStream(certFile)) {
            return CertificateFactory.getInstance("X.509").generateCertificate(cert);
        }
    }

    private static void writeCertificateToFile(@NonNull Context context, @NonNull Certificate certificate)
            throws CertificateEncodingException, IOException {
        File certFile = new File(context.getFilesDir(), "phonebridge-cert.pem");
        BASE64Encoder encoder = new BASE64Encoder();
        try (OutputStream os = new FileOutputStream(certFile)) {
            os.write(X509Factory.BEGIN_CERT.getBytes(StandardCharsets.UTF_8));
            os.write('\n');
            encoder.encode(certificate.getEncoded(), os);
            os.write('\n');
            os.write(X509Factory.END_CERT.getBytes(StandardCharsets.UTF_8));
        }
    }

    @Nullable
    private static PrivateKey readPrivateKeyFromFile(@NonNull Context context)
            throws IOException, NoSuchAlgorithmException, InvalidKeySpecException {
        File privateKeyFile = new File(context.getFilesDir(), "phonebridge-private.key");
        if (!privateKeyFile.exists()) {
            return null;
        }
        byte[] privateKeyBytes = new byte[(int) privateKeyFile.length()];
        try (InputStream is = new FileInputStream(privateKeyFile)) {
            is.read(privateKeyBytes);
        }
        KeyFactory keyFactory = KeyFactory.getInstance("RSA");
        EncodedKeySpec privateKeySpec = new PKCS8EncodedKeySpec(privateKeyBytes);
        return keyFactory.generatePrivate(privateKeySpec);
    }

    private static void writePrivateKeyToFile(@NonNull Context context, @NonNull PrivateKey privateKey)
            throws IOException {
        File privateKeyFile = new File(context.getFilesDir(), "phonebridge-private.key");
        try (OutputStream os = new FileOutputStream(privateKeyFile)) {
            os.write(privateKey.getEncoded());
        }
    }
}
